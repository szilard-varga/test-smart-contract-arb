/**
 *Submitted for verification at Arbiscan on 2023-06-21
*/

// SPDX-License-Identifier: MIT

    pragma solidity 0.6.12;

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
        function transfer(address recipient, uint256 amount)
            external
            returns (bool);

        /**
        * @dev Returns the remaining number of tokens that `spender` will be
        * allowed to spend on behalf of `owner` through {transferFrom}. This is
        * zero by default.
        *
        * This value changes when {approve} or {transferFrom} are called.
        */
        function allowance(address owner, address spender)
            external
            view
            returns (uint256);

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
        event Approval(
            address indexed owner,
            address indexed spender,
            uint256 value
        );
    }

    /**
    * @dev Wrappers over Solidity's arithmetic operations with added overflow
    * checks.
    *
    * Arithmetic operations in Solidity wrap on overflow. This can easily result
    * in bugs, because programmers usually assume that an overflow raises an
    * error, which is the standard behavior in high level programming languages.
    * `SafeMath` restores this intuition by reverting the transaction when an
    * operation overflows.
    *
    * Using this library instead of the unchecked operations eliminates an entire
    * class of bugs, so it's recommended to use it always.
    */
    library SafeMath {
        /**
        * @dev Returns the addition of two unsigned integers, with an overflow flag.
        *
        * _Available since v3.4._
        */
        function tryAdd(uint256 a, uint256 b)
            internal
            pure
            returns (bool, uint256)
        {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }

        /**
        * @dev Returns the substraction of two unsigned integers, with an overflow flag.
        *
        * _Available since v3.4._
        */
        function trySub(uint256 a, uint256 b)
            internal
            pure
            returns (bool, uint256)
        {
            if (b > a) return (false, 0);
            return (true, a - b);
        }

        /**
        * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
        *
        * _Available since v3.4._
        */
        function tryMul(uint256 a, uint256 b)
            internal
            pure
            returns (bool, uint256)
        {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }

        /**
        * @dev Returns the division of two unsigned integers, with a division by zero flag.
        *
        * _Available since v3.4._
        */
        function tryDiv(uint256 a, uint256 b)
            internal
            pure
            returns (bool, uint256)
        {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }

        /**
        * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
        *
        * _Available since v3.4._
        */
        function tryMod(uint256 a, uint256 b)
            internal
            pure
            returns (bool, uint256)
        {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }

        /**
        * @dev Returns the addition of two unsigned integers, reverting on
        * overflow.
        *
        * Counterpart to Solidity's `+` operator.
        *
        * Requirements:
        *
        * - Addition cannot overflow.
        */
        function add(uint256 a, uint256 b) internal pure returns (uint256) {
            uint256 c = a + b;
            require(c >= a, "SafeMath: addition overflow");
            return c;
        }

        /**
        * @dev Returns the subtraction of two unsigned integers, reverting on
        * overflow (when the result is negative).
        *
        * Counterpart to Solidity's `-` operator.
        *
        * Requirements:
        *
        * - Subtraction cannot overflow.
        */
        function sub(uint256 a, uint256 b) internal pure returns (uint256) {
            require(b <= a, "SafeMath: subtraction overflow");
            return a - b;
        }

        /**
        * @dev Returns the multiplication of two unsigned integers, reverting on
        * overflow.
        *
        * Counterpart to Solidity's `*` operator.
        *
        * Requirements:
        *
        * - Multiplication cannot overflow.
        */
        function mul(uint256 a, uint256 b) internal pure returns (uint256) {
            if (a == 0) return 0;
            uint256 c = a * b;
            require(c / a == b, "SafeMath: multiplication overflow");
            return c;
        }

        /**
        * @dev Returns the integer division of two unsigned integers, reverting on
        * division by zero. The result is rounded towards zero.
        *
        * Counterpart to Solidity's `/` operator. Note: this function uses a
        * `revert` opcode (which leaves remaining gas untouched) while Solidity
        * uses an invalid opcode to revert (consuming all remaining gas).
        *
        * Requirements:
        *
        * - The divisor cannot be zero.
        */
        function div(uint256 a, uint256 b) internal pure returns (uint256) {
            require(b > 0, "SafeMath: division by zero");
            return a / b;
        }

        /**
        * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
        * reverting when dividing by zero.
        *
        * Counterpart to Solidity's `%` operator. This function uses a `revert`
        * opcode (which leaves remaining gas untouched) while Solidity uses an
        * invalid opcode to revert (consuming all remaining gas).
        *
        * Requirements:
        *
        * - The divisor cannot be zero.
        */
        function mod(uint256 a, uint256 b) internal pure returns (uint256) {
            require(b > 0, "SafeMath: modulo by zero");
            return a % b;
        }

        /**
        * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
        * overflow (when the result is negative).
        *
        * CAUTION: This function is deprecated because it requires allocating memory for the error
        * message unnecessarily. For custom revert reasons use {trySub}.
        *
        * Counterpart to Solidity's `-` operator.
        *
        * Requirements:
        *
        * - Subtraction cannot overflow.
        */
        function sub(
            uint256 a,
            uint256 b,
            string memory errorMessage
        ) internal pure returns (uint256) {
            require(b <= a, errorMessage);
            return a - b;
        }

        /**
        * @dev Returns the integer division of two unsigned integers, reverting with custom message on
        * division by zero. The result is rounded towards zero.
        *
        * CAUTION: This function is deprecated because it requires allocating memory for the error
        * message unnecessarily. For custom revert reasons use {tryDiv}.
        *
        * Counterpart to Solidity's `/` operator. Note: this function uses a
        * `revert` opcode (which leaves remaining gas untouched) while Solidity
        * uses an invalid opcode to revert (consuming all remaining gas).
        *
        * Requirements:
        *
        * - The divisor cannot be zero.
        */
        function div(
            uint256 a,
            uint256 b,
            string memory errorMessage
        ) internal pure returns (uint256) {
            require(b > 0, errorMessage);
            return a / b;
        }

        /**
        * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
        * reverting with custom message when dividing by zero.
        *
        * CAUTION: This function is deprecated because it requires allocating memory for the error
        * message unnecessarily. For custom revert reasons use {tryMod}.
        *
        * Counterpart to Solidity's `%` operator. This function uses a `revert`
        * opcode (which leaves remaining gas untouched) while Solidity uses an
        * invalid opcode to revert (consuming all remaining gas).
        *
        * Requirements:
        *
        * - The divisor cannot be zero.
        */
        function mod(
            uint256 a,
            uint256 b,
            string memory errorMessage
        ) internal pure returns (uint256) {
            require(b > 0, errorMessage);
            return a % b;
        }
    }

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
            // solhint-disable-next-line no-inline-assembly
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
            require(
                address(this).balance >= amount,
                "Address: insufficient balance"
            );

            // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
            (bool success, ) = recipient.call{value: amount}("");
            require(
                success,
                "Address: unable to send value, recipient may have reverted"
            );
        }

        /**
        * @dev Performs a Solidity function call using a low level `call`. A
        * plain`call` is an unsafe replacement for a function call: use this
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
        function functionCall(address target, bytes memory data)
            internal
            returns (bytes memory)
        {
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
            return
                functionCallWithValue(
                    target,
                    data,
                    value,
                    "Address: low-level call with value failed"
                );
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
            require(
                address(this).balance >= value,
                "Address: insufficient balance for call"
            );
            require(isContract(target), "Address: call to non-contract");

            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory returndata) = target.call{value: value}(
                data
            );
            return _verifyCallResult(success, returndata, errorMessage);
        }

        /**
        * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
        * but performing a static call.
        *
        * _Available since v3.3._
        */
        function functionStaticCall(address target, bytes memory data)
            internal
            view
            returns (bytes memory)
        {
            return
                functionStaticCall(
                    target,
                    data,
                    "Address: low-level static call failed"
                );
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

            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory returndata) = target.staticcall(data);
            return _verifyCallResult(success, returndata, errorMessage);
        }

        /**
        * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
        * but performing a delegate call.
        *
        * _Available since v3.4._
        */
        function functionDelegateCall(address target, bytes memory data)
            internal
            returns (bytes memory)
        {
            return
                functionDelegateCall(
                    target,
                    data,
                    "Address: low-level delegate call failed"
                );
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

            // solhint-disable-next-line avoid-low-level-calls
            (bool success, bytes memory returndata) = target.delegatecall(data);
            return _verifyCallResult(success, returndata, errorMessage);
        }

        function _verifyCallResult(
            bool success,
            bytes memory returndata,
            string memory errorMessage
        ) private pure returns (bytes memory) {
            if (success) {
                return returndata;
            } else {
                // Look for revert reason and bubble it up if present
                if (returndata.length > 0) {
                    // The easiest way to bubble the revert reason is using memory via assembly

                    // solhint-disable-next-line no-inline-assembly
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
        using SafeMath for uint256;
        using Address for address;

        function safeTransfer(
            IERC20 token,
            address to,
            uint256 value
        ) internal {
            _callOptionalReturn(
                token,
                abi.encodeWithSelector(token.transfer.selector, to, value)
            );
        }

        function safeTransferFrom(
            IERC20 token,
            address from,
            address to,
            uint256 value
        ) internal {
            _callOptionalReturn(
                token,
                abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
            );
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
            // solhint-disable-next-line max-line-length
            require(
                (value == 0) || (token.allowance(address(this), spender) == 0),
                "SafeERC20: approve from non-zero to non-zero allowance"
            );
            _callOptionalReturn(
                token,
                abi.encodeWithSelector(token.approve.selector, spender, value)
            );
        }

        function safeIncreaseAllowance(
            IERC20 token,
            address spender,
            uint256 value
        ) internal {
            uint256 newAllowance = token.allowance(address(this), spender).add(
                value
            );
            _callOptionalReturn(
                token,
                abi.encodeWithSelector(
                    token.approve.selector,
                    spender,
                    newAllowance
                )
            );
        }

        function safeDecreaseAllowance(
            IERC20 token,
            address spender,
            uint256 value
        ) internal {
            uint256 newAllowance = token.allowance(address(this), spender).sub(
                value,
                "SafeERC20: decreased allowance below zero"
            );
            _callOptionalReturn(
                token,
                abi.encodeWithSelector(
                    token.approve.selector,
                    spender,
                    newAllowance
                )
            );
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

            bytes memory returndata = address(token).functionCall(
                data,
                "SafeERC20: low-level call failed"
            );
            if (returndata.length > 0) {
                // Return data is optional
                // solhint-disable-next-line max-line-length
                require(
                    abi.decode(returndata, (bool)),
                    "SafeERC20: ERC20 operation did not succeed"
                );
            }
        }
    }

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

        constructor() internal {
            _status = _NOT_ENTERED;
        }

        /**
        * @dev Prevents a contract from calling itself, directly or indirectly.
        * Calling a `nonReentrant` function from another `nonReentrant`
        * function is not supported. It is possible to prevent this from happening
        * by making the `nonReentrant` function external, and make it call a
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

    /**
    * @dev Standard math utilities missing in the Solidity language.
    */
    library Math {
        /**
        * @dev Returns the largest of two numbers.
        */
        function max(uint256 a, uint256 b) internal pure returns (uint256) {
            return a >= b ? a : b;
        }

        /**
        * @dev Returns the smallest of two numbers.
        */
        function min(uint256 a, uint256 b) internal pure returns (uint256) {
            return a < b ? a : b;
        }

        /**
        * @dev Returns the average of two numbers. The result is rounded towards
        * zero.
        */
        function average(uint256 a, uint256 b) internal pure returns (uint256) {
            // (a + b) / 2 can overflow, so we distribute
            return (a / 2) + (b / 2) + (((a % 2) + (b % 2)) / 2);
        }
    }
    interface IRewardPool {
        function deposit(uint256 _pid, uint256 _amount) external;

        function withdraw(uint256 _pid) external;

        function pendingReward(uint256 _pid, address _user)
            external
            view
            returns (uint256);


        function poolLength() external view returns (uint256);

        function getPoolInfo(uint256 _pid)
            external
            view
            returns (address _lp, uint256 _accTokenPerShare,uint256 _lockedTime,bool _isStarted);


    }

    // Note that this pool has no minter key of Token (rewards).
    // Instead, the governance will call Token distributeReward method and send reward to this pool at the beginning.
    contract RewardPool is IRewardPool, ReentrancyGuard {
        using SafeMath for uint256;
        using SafeERC20 for IERC20;

        // governance
        address public operator;

        // Info of each user.
        struct UserInfo {
            uint256 amount; // How many LP tokens the user has provided.
            uint256 rewardDebt; // Reward debt. See explanation below.
            uint256 lastDepositTime;
        }

        // Info of each pool.
        struct PoolInfo {
            IERC20 depositToken; // Address of LP token contract.
            uint256 accTokenPerShare; // Accumulated Token per share. See below.
            bool isStarted; 
            uint256 lockedTime; // if lastRewardTime has passed
            
        }
        IERC20 public rewardToken;
        address  insFund;
        bool public emergency;
        uint256 pendingRewardDebt;
        // Info of each pool.
        PoolInfo[] public poolInfo;

        // Info of each user that stakes LP tokens.
        mapping(uint256 => mapping(address => UserInfo)) public userInfo;

        uint256 public withdrawEarlyFee; // 10000(100%)

        event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
        event Withdraw(address indexed user, uint256 indexed pid, uint256 amount,uint256 reward);
        event EmergencyWithdraw(
            address indexed user,
            uint256 indexed pid,
            uint256 amount );
        event RewardPaid(address indexed user, uint256 amount);

        constructor(IERC20 _rewardToken,uint256  _withdrawEarlyFee,address _fund) public {
 
            operator = msg.sender;
            withdrawEarlyFee = _withdrawEarlyFee;
            insFund = _fund;
            emergency = false;
            pendingRewardDebt = 0;
            rewardToken = _rewardToken;
        }

        modifier onlyOperator() {
            require(
                operator == msg.sender,
                "TokenRewardPool: caller is not the operator"
            );
            _;
        }

        function poolLength() external view override returns (uint256) {
            return poolInfo.length;
        }

        function getPoolInfo(uint256 _pid)
            external
            view
            override
            returns (address _lp, uint256 _accTokenPerShare,uint256 _lockedTime,bool _isStarted)
        {
            PoolInfo memory pool = poolInfo[_pid];
            _lp = address(pool.depositToken);
            _accTokenPerShare = pool.accTokenPerShare;
            _lockedTime = pool.lockedTime;
            _isStarted = pool.isStarted;
        }


        // Add a new token to the pool. Can only be called by the owner.
        function add(
            IERC20 _depositToken, // Address of LP token contract.
            uint256 _accTokenPerShare, // Accumulated Token per share. See below.
            uint256 _lockedTime // if lastRewardTime has passed
        ) public onlyOperator {

            poolInfo.push(
                PoolInfo({
                    depositToken: _depositToken,
                    accTokenPerShare: _accTokenPerShare,
                    isStarted : true,
                    lockedTime: _lockedTime
                })
            );
        }

        function enableEmergency() public onlyOperator {
           emergency = !emergency; // 10000(100%) , eg: 500(5%)
        }

        function setWithdrawEarlyFee(uint256 _withdrawEarlyFee) public onlyOperator {
           withdrawEarlyFee = _withdrawEarlyFee; // 10000(100%) , eg: 500(5%)
        }
        // Update the given pool's Token allocation point. Can only be called by the owner.
        function setPoolTokenPerShare(uint256 _pid, uint256 _accTokenPerShare) public onlyOperator {
            PoolInfo storage pool = poolInfo[_pid];
            pool.accTokenPerShare = _accTokenPerShare;
        }

        // Update the given pool's Token locked time. Can only be called by the owner.
        function setPoolLockedTime(uint256 _pid, uint256 _lockedTime)
            public
            onlyOperator
        {
            PoolInfo storage pool = poolInfo[_pid];
            pool.lockedTime = _lockedTime;
        }

        function stopPool(uint256 _pid)
            public
            onlyOperator
        {
            PoolInfo storage pool = poolInfo[_pid];
            pool.isStarted = !pool.isStarted;
        }


        // View function to see pending Tokens on frontend.
        function pendingReward(uint256 _pid, address _user)
            public
            view
            override
            returns (uint256)
        {
            UserInfo storage user = userInfo[_pid][_user];
            return user.rewardDebt;
        }

       

        function unfrozenStakeTime(uint256 _pid, address _account)
        public
        view
        returns (uint256)
    {
        return
                (userInfo[_pid][_account].lastDepositTime + poolInfo[_pid].lockedTime );
    }


        

        // Deposit LP tokens.
        function deposit(uint256 _pid, uint256 _amount)
            external
            override
            nonReentrant
        {
            PoolInfo storage pool = poolInfo[_pid];
            require(pool.isStarted == true,"!pool");
            UserInfo storage user = userInfo[_pid][msg.sender];
            if (_amount > 0) {
               pool.depositToken.safeTransferFrom(msg.sender, address(this), _amount);
                user.amount = user.amount.add(_amount);
            }
            if(user.rewardDebt > 0 ){
                pendingRewardDebt = pendingRewardDebt.sub(user.rewardDebt);
            }
            user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e18);
            pendingRewardDebt = pendingRewardDebt.add(user.rewardDebt);
            user.lastDepositTime = block.timestamp;
            emit Deposit(msg.sender, _pid, _amount);
        }

        // Withdraw LP tokens.
        function _withdraw(
            address _account,
            uint256 _pid
        ) internal {
            PoolInfo storage pool = poolInfo[_pid];
            UserInfo storage user = userInfo[_pid][_account];
            uint256 _amount = user.amount;
            require(
                    block.timestamp >= unfrozenStakeTime(_pid, msg.sender),
                    "RewardPool: locked!"
                );

            uint256 _pending = user.rewardDebt;
            if (_pending > 0) {
                safeTokenTransfer( rewardToken,_account, _pending);
                emit RewardPaid(_account, _pending);
            }
           
            pool.depositToken.safeTransfer(_account, _amount);
            user.rewardDebt = 0;
            user.amount = 0;
            emit Withdraw(_account, _pid, _amount,_pending);
        }

        function withdraw(uint256 _pid) external override nonReentrant {
            _withdraw(msg.sender, _pid);
        }
        // Withdraw without caring about rewards. EMERGENCY ONLY.
        function earlyWithdraw(uint256 _pid) external {
            PoolInfo storage pool = poolInfo[_pid];
            UserInfo storage user = userInfo[_pid][msg.sender];
            uint256 _fee = user.amount.mul(withdrawEarlyFee).div(10000);
            uint256  _amount = user.amount.sub(_fee);
            uint256 _pending = user.rewardDebt;
            if (_pending > 0) {
                safeTokenTransfer( rewardToken,insFund, _pending);
            }

            user.amount = 0;
            user.rewardDebt = 0;
            pool.depositToken.safeTransfer(msg.sender, _amount);
            pool.depositToken.safeTransfer(insFund, _fee);
            emit EmergencyWithdraw(msg.sender, _pid, _amount);
        }
        // Withdraw without caring about rewards. EMERGENCY ONLY.
        function emergencyWithdraw(uint256 _pid) external {
            require(emergency == true,"!emergency");
            PoolInfo storage pool = poolInfo[_pid];
            UserInfo storage user = userInfo[_pid][msg.sender];
            uint256 _amount = user.amount;
            user.amount = 0;
            user.rewardDebt = 0;
            pool.depositToken.safeTransfer(msg.sender, _amount);
            emit EmergencyWithdraw(msg.sender, _pid, _amount);
        }

        // Safe rewardToken transfer function, just in case if rounding error causes pool to not have enough Tokens.
        function safeTokenTransfer(IERC20 _token, address _to, uint256 _amount) internal {
            uint256 _rewardTokenBal = _token.balanceOf(address(this));
            if (_rewardTokenBal > 0) {
                if (_amount > _rewardTokenBal) {
                    _token.safeTransfer(_to, _rewardTokenBal);
                } else {
                    _token.safeTransfer(_to, _amount);
                }
            }
        }
        
        // Deposit LP tokens.
        function depositRewardonlyForDAO(uint256 _amount)
            external
            nonReentrant
        {
           
            require(pendingRewardDebt >= _amount,"!pendingRewardDebt");
            rewardToken.safeTransferFrom(msg.sender, address(this), _amount);

            
        }
        function setOperator(address _operator) external onlyOperator {
            operator = _operator;
        }

    }