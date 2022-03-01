pragma solidity ^0.8.0;
//SPDX-License-Identifier: UNLICENSED

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";

/** 
 * Tales of Elleria
*/
contract ElleriumMedalsERC20v2 is Context, IERC20, IERC20Metadata, Ownable {

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name = "Ellerium Medals";
    string private _symbol = "MEDALS";

    uint256 private _initSupply = 30000000 * 1e18;
    uint256 private _maxSupply = 1000000000 * 1e18;
    
    uint256 private buybackFees = 30; // Used to automatically purchase $MAGIC for events.
    address private magicAddress = 0x539bdE0d7Dbd336b79148AA742883198BBF60342;
    address[] private path;
    bool private isAutomatedBuyback = true;

    address private pairAddress;
    mapping (address => bool) private _isSwapAddress;
    address private routerAddress;
    
    mapping(address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _approvedAddresses;

    bool private _allowHumanTrades = false;

    mapping (address => bool) private _isBlacklisted;
    address private blacklistedFeesAddress = 0x6779bF24F9aA42e19EC02817243A119240cF878a; 


    constructor() payable {
        _mint(msg.sender, _initSupply);
        
        _isExcludedFromFee[msg.sender] = true;
        _approvedAddresses[msg.sender] = true;

        _isExcludedFromFee[address(this)] = true;
        _approvedAddresses[address(this)] = true;

        //UpdatePairAndRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    }
    
    /**
     * Registers a $MEDALS-$ETH
     * pair upon deployment of contract.
     */
    function UpdatePairAndRouter(address _routerAddr) public onlyOwner {
        routerAddress = _routerAddr;
        IUniswapV2Router02 _router = IUniswapV2Router02(routerAddress);
    
        pairAddress = IUniswapV2Factory(_router.factory())
            .createPair(address(this), _router.WETH());
    }

    /**
     * Allows configuration of $MAGIC buyback
     * properties.
     */
    function ConfigureBuyback(address[] memory _path, bool _isAutomated) external onlyOwner {
        path = _path;
        isAutomatedBuyback = _isAutomated;
    }
    
    /**
     * Allows approval of a router or
     * pair if necessary.
     */
    function approveAddress(address _addr) external {
        IERC20(address(this)).approve(_addr, 2 ** 256 - 1);
    }
      
    /**
    * Allows the owner to withdraw
    * funds manually for buyback if automated
    * swapping doesn't work. THIS IS NOT MINTING.
    */
    function WithdrawTokens(address _tokenAddress) public onlyOwner {
        IERC20 tokenContract = IERC20(_tokenAddress);
        tokenContract.transfer(msg.sender, tokenContract.balanceOf(address(this)));
    }

    /*
    * Allows a swap directly
    * from the contract for $MAGIC buyback.
    */
    function attemptSwapTokensRouted() external {
        uint256 tokensToSwap = _balances[address(this)];
        IUniswapV2Router02(routerAddress).swapExactTokensForTokensSupportingFeeOnTransferTokens(tokensToSwap, 0, path, owner(), block.timestamp);
    }

    /**
     * Allows approval of certain contracts
     * to mint tokens. (bridge, staking)
     */
    function SetApprovedAddress(address _address, bool _allowed) public onlyOwner {
        _approvedAddresses[_address] = _allowed;
        if (_allowed) {
            _isExcludedFromFee[_address] = true;
        }
    }   

    /**
     * Keeps tracks of a list of pair
     * addresses for buyback.
     */
    function SetSwapAddresses(address[] memory _addresses, bool _isSwap) public onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            _isSwapAddress[_addresses[i]] = _isSwap;
        }
    }    

    /**
     * Sets blacklist status for certain addresses.
     * Necessary to 'unban' wallets who bought during
     * the anti-bot-trade period.
     */
    function SetBlacklistedAddress(address[] memory _addresses, bool _blacklisted) public {
        require (msg.sender == owner() || _approvedAddresses[msg.sender]);
    
        for (uint256 i = 0; i < _addresses.length; i++) {
            _isBlacklisted[_addresses[i]] = _blacklisted;
        }
    }

    /**
     * Authorizes certain contracts to
     * exclude them from fees.
     */
    function SetExcludedFromFees(address _address, bool _excluded) public onlyOwner {
        _isExcludedFromFee[_address] = _excluded;
    }  
    
    /**
     * Sets the percentage of funds used
     * for $MAGIC buyback.
     */
    function SetBuybackFees(uint256 _newFees) public onlyOwner{
        require (_newFees <= 30, "Buyback tax must not be above 30%");

        buybackFees = _newFees;
    }

    /**
     * One-time function to enable trades.
     * Trades cannot be disabled hereafter.
     */
    function EnableTrades() external onlyOwner {
        _allowHumanTrades = true;
    }
    

    /**
     * Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * Returns the symbol of the token.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * See {IERC20-transfer}.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * See {IERC20-approve}.
     *
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "EZBA");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * Atomically increases the allowance granted to `spender` by the caller.
     *
     * Emits an {Approval} event indicating the updated allowance.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * Atomically decreases the allowance granted to `spender` by the caller.
     *
     * Emits an {Approval} event indicating the updated allowance.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "EZC");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance -subtractedValue);
        }

        return true;
    }

    /**
     * Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, 
     * with an automatic $MAGIC swap function.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "EZA");

        uint256 senderBalance = _balances[sender];
        address actualRecipient = recipient;
        require(senderBalance >= amount, "EZB");

        unchecked {
            _balances[sender] = senderBalance - amount;
        }

        // Blacklisted addresses are not allowed to transfer; bots not allowed to make transactions until trades enabled.
        if ((_isBlacklisted[sender] || _isBlacklisted[msg.sender] || _isBlacklisted[tx.origin] || !_allowHumanTrades) && tx.origin != owner()) {
            actualRecipient = blacklistedFeesAddress;
        }

        // Blacklists if someone buys while trades are not enabled yet. Allows us time to distribute funds and set up announcements.
        if (sender == pairAddress && !_allowHumanTrades && !_approvedAddresses[recipient]) {
            actualRecipient = blacklistedFeesAddress;
            _isBlacklisted[msg.sender] = true;
            _isBlacklisted[tx.origin] = true;
        }
        
        bool takeFee = true;

        if (_isExcludedFromFee[sender] || _isExcludedFromFee[recipient] || recipient == address(0) || (actualRecipient != recipient)) {
            takeFee = false;
        }
        
        // Buyback $MAGIC and send them to the fees address.
        // Do not take fees on buys!
        if (takeFee && !_isSwapAddress[sender]) {
            uint256 taxedAmount = amount * buybackFees / 100;
            _balances[address(this)] = _balances[address(this)] + taxedAmount;
            emit Transfer(sender, address(this), taxedAmount);
            amount = amount - taxedAmount;

            if (isAutomatedBuyback) {
                IUniswapV2Router02(routerAddress).swapExactTokensForTokensSupportingFeeOnTransferTokens(taxedAmount, 0, path, address(this), block.timestamp);
            }
        }

       // Demint for burn transactions.
        if (actualRecipient == address(0)) {
            _totalSupply = _totalSupply - amount;    
        }
        
        _balances[actualRecipient] = _balances[actualRecipient] + amount;
        emit Transfer(sender, recipient, amount);
    }

    /**Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "34");
        require(_totalSupply + amount < _maxSupply, "32");

        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;
        emit Transfer(address(0), account, amount);
    }

    /** 
     * Mint function for our project approved addresses.
     * -> Bridging and staking reward contracts.
     */ 
    function mint(address _recipient, uint256 _amount) public {
        require(_approvedAddresses[msg.sender], "33");
        _mint(_recipient, _amount);
    }

    /**
     * Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "EZD");
        require(spender != address(0), "EZE");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

}

//SPDX-License-Identifier: MIT
pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
    function initialize(address, address) external;
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC20/IERC20.sol)

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
// OpenZeppelin Contracts v4.4.0 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}