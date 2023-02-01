/**
 *Submitted for verification at Arbiscan on 2023-01-31
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


// 
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)
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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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

// 
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)
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

// 
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)
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

// 
// Inheritance
// https://docs.synthetix.io/contracts/Pausable
abstract contract Pausable is Ownable {
    uint256 public lastPauseTime;
    bool public paused;

    constructor() {
        // This contract is abstract, and thus cannot be instantiated directly
        require(owner() != address(0), "Owner must be set");
        // Paused will be false, and lastPauseTime will be 0 upon initialisation
    }

    /**
     * @notice Change the paused state of the contract
     * @dev Only the contract owner may call this.
     */
    function setPaused(bool _paused) external onlyOwner {
        // Ensure we're actually changing the state before we do anything
        if (_paused == paused) {
            return;
        }

        // Set our paused state.
        paused = _paused;

        // If applicable, set the last pause time.
        if (paused) {
            lastPauseTime = block.timestamp;
        }

        // Let everyone know that our pause state has changed.
        emit PauseChanged(paused);
    }

    event PauseChanged(bool isPaused);

    modifier notPaused {
        require(
            !paused,
            "This action cannot be performed while the contract is paused"
        );
        _;
    }
}

// 
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)
/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// 
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)
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
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
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

// 
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)
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

// 
interface ISTLRSettingsV1 {
    function STLR() external view returns (address);
    function USDC() external view returns (address);

    function dao() external view returns (address);
    function manager() external view returns (address);
    function treasury() external view returns (address);
    function helper() external view returns (address);
    function presale() external view returns (address);
    function oracle() external view returns (address);
    function paused() external view returns (bool);

    function isOperator(address) external view returns (bool);
    function isExemptFromFee(address) external view returns (bool);
    function isMarketPair(address) external view returns (bool);

    function rewardFeePercentage() external view returns (uint);
    function maxRewardFee() external view returns (uint);
    function claimFee() external view returns (uint);
    function claimCooldown() external view returns (uint);
    function interestRate() external view returns (uint);
    function maxRotCount() external view returns (uint);
    function rotDeduction() external view returns (uint);
    function farmingClaimCooldown() external view returns (uint);
    function farmingWithdrawDelay() external view returns (uint);

    function transferLimit() external view returns (uint);
    function walletMax() external view returns (uint);
    function feeOnTransfer() external view returns (bool);

    function REWARD_FREQUENCY() external view returns (uint);
    function BASE_DENOMINATOR() external view returns (uint);
    function MAX_SETTLEMENTS() external view returns (uint);
    function LOCKED_PERCENT() external view returns (uint);
    function SELL_FEE() external view returns (uint);
}

// 
interface ISettleverseDao {
    function treasury() external view returns (address);
    function settings() external view returns (address);
    function settlementTypes(uint) external view returns (bool, uint, uint, uint);
    function settCount() external view returns (uint);
    function accounts(address) external view returns (bool, uint, uint, uint, uint, uint, uint);
    function earned(address) external view returns (uint);

    function declare(address, uint) external;
    function settle(address, uint, uint) external;
    function claim(address, bool) external returns (uint);
    function compound(address, uint, uint, uint, uint) external;
    function mint(address, uint, uint) external;
}

// 
interface ISTLROracle {
    function PRECISION() external view returns (uint);
    function latestPrice() external view returns (uint);
}

// 
contract STLRManagerV1 is Ownable, ReentrancyGuard {
    ISettleverseDao public stlrDao;
    IERC20Metadata public immutable stlr;
    IERC20Metadata public immutable usdc;

    uint private feeSlippage = 50; // 0.5%
    uint private feeSlippageBase = 1000;

    constructor(
        address _stlrDao
    ) {
        stlrDao = ISettleverseDao(_stlrDao);
        stlr = IERC20Metadata(ISTLRSettingsV1(stlrDao.settings()).STLR());
        usdc = IERC20Metadata(ISTLRSettingsV1(stlrDao.settings()).USDC());
    }

    /** VIEW FUNCTIONS */

    function getRewardFee(
        address account
    )
        public
        view
        returns (uint fee)
    {
        uint rewardFeePercentage = ISTLRSettingsV1(stlrDao.settings()).rewardFeePercentage();
        uint maxRewardFee = ISTLRSettingsV1(stlrDao.settings()).maxRewardFee();
        uint denominator = ISTLRSettingsV1(stlrDao.settings()).BASE_DENOMINATOR();

        ISTLROracle oracle = ISTLROracle(ISTLRSettingsV1(stlrDao.settings()).oracle());
        uint latestPrice = oracle.latestPrice();
        uint precision = oracle.PRECISION();

        uint reward = stlrDao.earned(account);
        uint rewardFee = (reward * rewardFeePercentage / denominator) * latestPrice / precision;
        fee = (rewardFee > maxRewardFee) ? maxRewardFee : rewardFee; 
    }

    /** INTERNAL FUNCTIONS */

    function _claim(
        address account,
        bool _compound
    )
        internal
        returns (uint rewards)
    {
        rewards = stlrDao.claim(account, _compound);
    }

    /** EXTERNAL FUNCTIONS */

    function declare(
        uint _faction
    ) 
        external 
        nonReentrant
    {
        stlrDao.declare(msg.sender, _faction);
    }

    function settle(
        uint settlementType, 
        uint count
    ) 
        external 
        nonReentrant 
    {
        require(count > 0, 'Count must be more than zero');
        require(settlementType >= 0 && settlementType < stlrDao.settCount(), 'Invalid settlement type');

        (, , uint stlrAmount, uint usdcAmount) = stlrDao.settlementTypes(settlementType);
        uint _stlr = count * stlrAmount * 10 ** stlr.decimals();
        uint _usdc = count * usdcAmount * 10 ** usdc.decimals();

        stlrDao.settle(msg.sender, settlementType, count);

        stlr.transferFrom(msg.sender, address(stlrDao), _stlr);
        usdc.transferFrom(msg.sender, stlrDao.treasury(), _usdc);
    }

    function claim(
    ) 
        external
        payable
        nonReentrant
        payFee(msg.sender)
    {
        _claim(msg.sender, false);
    }

    function compound(
        uint settlementType,
        uint count
    ) 
        external
        payable
        nonReentrant
        payFee(msg.sender)
    {
        require(count > 0, 'Count must be more than zero');
        require(settlementType >= 0 && settlementType < stlrDao.settCount(), 'Invalid settlement type');
        
        uint rewards = _claim(msg.sender, true);
        (, , uint stlrAmount, uint usdcAmount) = stlrDao.settlementTypes(settlementType);
        uint _stlr = count * stlrAmount * 10 ** stlr.decimals();
        uint _usdc = count * usdcAmount * 10 ** usdc.decimals();
        uint diff;
        uint fee;
        uint refund;
        if (rewards < _stlr) {
            diff = _stlr - rewards;
            require(stlr.balanceOf(msg.sender) >= diff, 'You do not have enough STLR to compound');
        } else {
            uint rest = rewards - _stlr;
            if (rest > 0) {
                fee = rest * ISTLRSettingsV1(stlrDao.settings()).claimFee() / 10000;
                refund = rest - fee;
            }
        }

        stlrDao.compound(msg.sender, settlementType, count, fee, refund);

        if (diff > 0) {
            stlr.transferFrom(msg.sender, address(stlrDao), diff);
        }
        usdc.transferFrom(msg.sender, stlrDao.treasury(), _usdc);
    }

    /** RESTRICTED FUNCTIONS */

    function setDao(
        address _dao
    ) 
        external 
        onlyOwner 
    {
        require(_dao != address(0), "Can not be null address");
        stlrDao = ISettleverseDao(_dao);
        emit DaoUpdated(_dao);
    }

    function setFeeSlippage(
        uint _feeSlippage
    )
        external
        onlyOwner
    {
        require(_feeSlippage <= feeSlippageBase, 'FEE_SLIPPAGE');
        feeSlippage = _feeSlippage;
        emit FeeSlippageUpdated(feeSlippage);
    }

    function recover(
        address token
    )
        external
        onlyOwner
    {
        uint balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner(), balance);
        emit Recovered(token, balance);
    }

    function recover() 
        external 
        onlyOwner 
    {
        uint balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
        emit Recovered(balance);
    }

    /** MODIFIERS */

    modifier payFee(
        address account
    ) {
        uint min = getRewardFee(account) * 
            (feeSlippageBase - feeSlippage) / 
            feeSlippageBase;

        require(msg.value >= min, 'REWARD_FEE');
        Address.sendValue(payable(stlrDao.treasury()), address(this).balance);

        _;
    }

    /** EVENTS */

    event DaoUpdated(address dao);
    event FeeSlippageUpdated(uint feeSlippage);
    event Recovered(address token, uint amount);
    event Recovered(uint amount);
}