// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IDeployment.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./Deployment.sol";

import "./types/UmamiAccessControlled.sol";


interface IRewardRouterV2 {
    function unstakeAndRedeemGlp(
        address _tokenOut,
        uint256 _glpAmount,
        uint256 _minOut,
        address _receiver
    ) external returns (uint256);
    function mintAndStakeGlp(
        address _token,
        uint256 _amount,
        uint256 _minUsdg,
        uint256 _minGlp
    ) external returns (uint256);
    function handleRewards(
        bool _shouldClaimGmx,
        bool _shouldStakeGmx,
        bool _shouldClaimEsGmx,
        bool _shouldStakeEsGmx,
        bool _shouldStakeMultiplierPoints,
        bool _shouldClaimWeth,
        bool _shouldConvertWethToEth
    ) external;
    function claimEsGmx() external;
}

interface IVester {
    function deposit(uint256 _amount) external;
}

interface IRewardTracker {
    function claimable(address _account) external view returns (uint256);
}

contract GLPDeployment is Deployment {
    using SafeERC20 for IERC20;

    address constant usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address constant esGmx = 0xf42Ae1D54fd613C9bb14810b0588FaAa09a426cA;
    address constant gmx = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
    address constant vGmx = 0x199070DDfd1CFb69173aa2F7e20906F26B363004;
    address constant sbfGmx = 0xd2D1162512F927a7e282Ef43a362659E4F2a728F;
    address constant fGlp = 0x4e971a87900b931fF39d1Aad67697F49835400b6;
    address constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; 
    address constant glpRewardRouter = 0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1;
    address constant stakedGlp = 0x1aDDD80E6039594eE970E5872D247bf0414C8903;
    address constant vester = 0xA75287d2f8b217273E7FCD7E86eF07D33972042E;
    address constant glpManager = 0x321F653eED006AD1C29D174e17d96351BDe22649;

    constructor(
        IDeploymentManager manager, 
        ITreasury treasury, 
        address sushiRouter) Deployment(manager, treasury, sushiRouter) {}

    function deposit(uint256 amount, bool fromTreasury) external override onlyDepositWithdrawer {
        if (fromTreasury) {
            treasury.manage(usdc, amount);
        } else {
            IERC20(usdc).safeTransferFrom(msg.sender, address(this), amount);
        }

        _deposit(amount);
    }

    function _deposit(uint256 amount) internal {
        IERC20(usdc).approve(glpManager, amount);
        uint256 amountWithSlippage = getSlippageAdjustedAmount(amount, 10 /* 1% */);
        IRewardRouterV2(glpRewardRouter).mintAndStakeGlp(usdc, amount, amountWithSlippage, 0 /* _minGlp */);

        emit Deposit(amount);
    }

    function withdraw(uint256 amount) public override onlyDepositWithdrawer {
        uint256 outputAmount = IRewardRouterV2(glpRewardRouter).unstakeAndRedeemGlp(usdc, amount, 0, address(this));
        IERC20(usdc).safeTransfer(address(treasury), outputAmount);

        emit Withdraw(amount);
    }

    function withdrawAll(bool dumpTokensForWeth) external override onlyDepositWithdrawer {
        uint256 glpAmount = IERC20(stakedGlp).balanceOf(address(this));
        withdraw(glpAmount);
        harvest(dumpTokensForWeth);
    }

    function harvest(bool dumpTokensForWeth) public override onlyDepositWithdrawerOrAutomation {
        uint256 wethAmount = IERC20(weth).balanceOf(address(this));
        uint256 gmxAmount = IERC20(gmx).balanceOf(address(this));

        // Claim GMX and WETH rewards, restake esGMX
        IRewardRouterV2(glpRewardRouter).handleRewards(true, false, true, true, true, true, false);

        wethAmount = IERC20(weth).balanceOf(address(this)) - wethAmount;
        gmxAmount = IERC20(gmx).balanceOf(address(this)) - gmxAmount;

        if (dumpTokensForWeth && gmxAmount > 0) {
            address[] memory path = new address[](2);
            path[0] = gmx;
            path[1] = weth;
            uint256 soldEthAmount = swapToken(path, gmxAmount, 0);
            uint256 totalEthAmount = soldEthAmount + wethAmount;
            distributeToken(weth, totalEthAmount);
        }
        else {
            distributeToken(weth, wethAmount);
            distributeToken(gmx, gmxAmount);
        }

        emit Harvest(dumpTokensForWeth);
    }

    function vestEsGmx() public onlyDepositWithdrawerOrAutomation {
        uint256 esGmxAmount = IERC20(esGmx).balanceOf(address(this));
        require(esGmxAmount > 0, "No esGMX to vest");
        IVester(vester).deposit(esGmxAmount);
    }

    function claimEsGmx() public onlyDepositWithdrawerOrAutomation {
        IRewardRouterV2(glpRewardRouter).handleRewards(false, false, true, false, false, false, false);
    }

    function compound() external override onlyDepositWithdrawerOrAutomation {
        IRewardRouterV2(glpRewardRouter).handleRewards(true, true, true, true, true, true, false);
    }

    function balance(address token) view public override returns (uint256) {
        if (token == stakedGlp) {
            // Normal GLP balance
            return IERC20(stakedGlp).balanceOf(address(this));
        }
        else if (token == vGmx) {
            // Vesting esGMX
            return IERC20(vGmx).balanceOf(address(this));
        }
        return 0;
    }

    function pendingRewards(address token) view public override returns (uint256) {
        if (token == weth) {
            // wETH rewards come from fGLP and sbfGMX
            uint256 fglpRewards = IRewardTracker(fGlp).claimable(address(this));
            uint256 sbfgmxRewards = IRewardTracker(sbfGmx).claimable(address(this));
            return fglpRewards + sbfgmxRewards;
        }
        return 0;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: Unlicense
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ITreasury {
    function manage( address _token, uint _amount ) external;
    function deposit( uint _amount, address _token, uint _profit ) external returns ( bool );
    function valueOf( address _token, uint _amount ) external view returns ( uint value_ );
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IDeployment {
    /**
     * @notice deposit from the treasury into the strategy
     */
    function deposit(uint256 amount, bool fromTreasury) external;

    /**
     * @notice withdraw from the strategy and return to the treasury
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice withdraw all funds from the strategy and harvest rewards    
     */
    function withdrawAll(bool dumpTokensForWeth) external; 
    
    /**
     * @notice retrieve all available rewards
     */
    function harvest(bool dumpTokensForWeth) external;

    /**
     * @notice harvests rewards and reinvests them
     */
    function compound() external;

    /**
     * @notice returns the balance of a token in the deployment
     */
    function balance(address token) external returns (uint256);

    /**
     * @notice return the amount of rewards waiting to be harvested
     */
    function pendingRewards(address token) external returns (uint256);

    /**
     * @notice withdraw tokens from the contract to the sender
     */
    function rescueToken(address token) external;

    /**
     * @notice withdraw eth from the contract to the sender
     */
    function rescueETH() external;

    /**
     * @notice perform arbitrary call on behalf of contract if something really bad happens
     */
    function rescueCall(address target, string calldata signature, bytes calldata parameters) external returns(bytes memory);
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IUniswapV2Router {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./interfaces/IDeployment.sol";
import "./interfaces/IDeploymentManager.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./types/UmamiAccessControlled.sol";


abstract contract Deployment is IDeployment, UmamiAccessControlled {
    using SafeERC20 for IERC20;

    ITreasury public immutable treasury;
    uint256 public constant SCALE = 1000;
    address public immutable sushiRouter;
    event Deposit(uint256 amount);
    event Withdraw(uint256 amount);
    event Harvest(bool dumpToken);
    event HarvestReward(address token, uint256 amount);
    event Compound();
    event SwapToken(address inputToken, uint256 inputAmount, address outputToken, uint256 outputAmount);

    constructor (
            IDeploymentManager manager, 
            ITreasury _treasury,
            address _sushiRouter
        ) UmamiAccessControlled(manager) {
        treasury = _treasury;
        sushiRouter = _sushiRouter;
    }

    function swapToken(address[] memory path, uint256 amount, uint256 minOutputAmount) internal returns (uint256) {
        if (minOutputAmount == 0) {
            uint256[] memory amountsOut = IUniswapV2Router(sushiRouter).getAmountsOut(amount, path);
            minOutputAmount = amountsOut[amountsOut.length - 1];
        }
        IERC20(path[0]).approve(sushiRouter, amount);
        uint256[] memory withdrawAmounts = IUniswapV2Router(sushiRouter).swapExactTokensForTokens(
            amount,
            minOutputAmount,
            path,
            address(this),
            block.timestamp
        );
        uint256 outputAmount = withdrawAmounts[path.length - 1];
        emit SwapToken(path[0], amount, path[path.length - 1], outputAmount);
        return outputAmount;
    }

    function getSlippageAdjustedAmount(uint256 amount, uint256 slippage) internal pure returns (uint256) {
        return (amount * (1*SCALE - slippage)) / SCALE;
    }

    function distributeToken(address token, uint256 amount) internal {
        address dest = deploymentManager.getRewardDestination();
        IERC20(token).safeTransfer(dest, amount);
    }

    function rescueToken(address token) external override onlyManager {
        IERC20(token).safeTransfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    function rescueETH() external override onlyManager {
        payable(msg.sender).transfer(address(this).balance);
    }

    function rescueCall(address target, string calldata signature, bytes calldata parameters) external override onlyManager returns(bytes memory) {
        (bool success, bytes memory data) = target.call(
            abi.encodePacked(bytes4(keccak256(bytes(signature))), parameters)
        );
        if (!success) {
            assembly {
                let ptr := mload(0x40)
                let size := returndatasize()
                returndatacopy(ptr, 0, size)
                revert(ptr, size)
            }
        }
        return data;
    }

}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/IAccessControl.sol";
import "../interfaces/IDeploymentManager.sol";


abstract contract UmamiAccessControlled {
    event ManagerUpdated(IDeploymentManager indexed authority);

    string UNAUTHORIZED = "UNAUTHORIZED"; // save gas

    IDeploymentManager public deploymentManager;

    constructor(IDeploymentManager manager) {
        deploymentManager = manager;
        emit ManagerUpdated(manager);
    }

    modifier onlyManager() {
        bytes32 role = deploymentManager.getManageRole();
        require(deploymentManager.hasRole(role, msg.sender), UNAUTHORIZED);
        _;
    }

    modifier onlyDepositWithdrawer() {
        bytes32 role = deploymentManager.getDepositWithdrawRole();
        require(deploymentManager.hasRole(role, msg.sender), UNAUTHORIZED);
        _;
    }

    modifier onlyDepositWithdrawerOrAutomation() {
        bytes32 depositer = deploymentManager.getDepositWithdrawRole();
        bytes32 automation = deploymentManager.getAutomationRole();
        require(deploymentManager.hasRole(depositer, msg.sender) || 
            deploymentManager.hasRole(automation, msg.sender), UNAUTHORIZED);
        _;
    }

    function setManager(IDeploymentManager manager) external onlyManager {
        deploymentManager = manager;
        emit ManagerUpdated(manager);
    }
}

// SPDX-License-Identifier: Unlicense
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/IAccessControl.sol";

interface IDeploymentManager is IAccessControl {
    function getRewardDestination() external view returns (address);
    function getManageRole() external view returns (bytes32);
    function getDepositWithdrawRole() external view returns (bytes32);
    function getAutomationRole() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}