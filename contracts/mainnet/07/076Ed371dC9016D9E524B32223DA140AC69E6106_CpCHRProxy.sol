// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initialized`
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initializing`
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20PermitUpgradeable {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../extensions/draft-IERC20PermitUpgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
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

    function safePermit(
        IERC20PermitUpgradeable token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../interfaces/IVeToken.sol";
import "../interfaces/IVoter.sol";
import "../interfaces/IVeDist.sol";
import "../interfaces/IMinter.sol";
import "../interfaces/ISolidlyRouter.sol";
import "../interfaces/ISolidlyGauge.sol";

contract CpCHRProxy is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Voted Gauges
    struct Gauges {
        address bribeGauge;
        address feeGauge;
        address[] bribeTokens;
        address[] feeTokens;
    }

    IERC20Upgradeable public CHR;
    IVeToken public ve;
    IVeDist public veDist;
    IVoter public solidVoter;
    ISolidlyRouter public router;

    address public cpCHR;

    // Vote weight decays linearly over time. Lock time cannot be more than `MAX_LOCK` (2 years).
    uint256 public constant MAX_LOCK = 365 days * 2;
    uint256 public constant MAX_RATE = 1e18;

    uint256 public mainTokenId;
    uint256 public reserveTokenId;
    uint256 public redeemTokenId;

    mapping(address => Gauges) public gauges;
    mapping(address => bool) public lpInitialized;
    mapping(address => ISolidlyRouter.Routes[]) public routes;

    address public extension;

    event SetCpCHR(address oldValue, address newValue);
    event AddedGauge(address gauge, address feeGauge, address[] bribeTokens, address[] feeTokens);
    event AddedRewardToken(address token);
    event SetRedeemTokenId(uint256 oldValue, uint256 newValue);

    event SetSolidVoter(address oldValue, address newValue);
    event SetVeDist(address oldValue, address newValue);

    function initialize(IVoter _solidVoter, ISolidlyRouter _router) public initializer {
        __Ownable_init();

        solidVoter = IVoter(_solidVoter);
        ve = IVeToken(solidVoter._ve());
        CHR = IERC20Upgradeable(ve.token());
        // IMinter _minter = IMinter(solidVoter.minter());
        // veDist = IVeDist(_minter._rewards_distributor());
        
        router = _router;
        CHR.safeApprove(address(ve), type(uint256).max);
    }

    modifier onlyCpCHR() {
        require(msg.sender == cpCHR, "Proxy: FORBIDDEN");
        _;
    }

    modifier onlyExtension() {
        require(msg.sender == extension, "Proxy: EXTENSION_FORBIDDEN");
        _;
    }

    function setCpCHR(address _cpCHR) external onlyOwner {
        require(address(cpCHR) == address(0), "Proxy: ALREADY_SET");
        emit SetCpCHR(cpCHR, _cpCHR);
        cpCHR = _cpCHR;
    }

    function createMainLock(uint256 _amount, uint256 _lock_duration) external onlyCpCHR {
        require(mainTokenId == 0, "Proxy: ASSIGNED");
        mainTokenId = ve.create_lock(_amount, _lock_duration);
    }

    function createReserveLock(uint256 _amount, uint256 _lock_duration) external onlyCpCHR {
        require(reserveTokenId == 0, "Proxy: ASSIGNED");
        reserveTokenId = ve.create_lock(_amount, _lock_duration);
        redeemTokenId = reserveTokenId;
    }

    function merge(uint256 _from, uint256 _to) external {
        require(_to == mainTokenId || _to == reserveTokenId, "Proxy: TO_TOKEN_INVALID");
        require(_from != mainTokenId && _from != reserveTokenId, "Proxy: NOT_MERGE_BUSINESS_TOKEN");
        require(ve.ownerOf(_from) == address(this), "Proxy: OWNER_IS_NOT_PROXY");
        ve.merge(_from, _to);
    }

    function increaseAmount(uint256 _tokenId, uint256 _amount) external onlyCpCHR {
        ve.increase_amount(_tokenId, _amount);
    }

    function increaseUnlockTime() external onlyCpCHR {
        uint256 unlockTime = (block.timestamp + MAX_LOCK) / 1 weeks * 1 weeks;
        (, uint256 mainEndTime) = ve.locked(mainTokenId);
        (, uint256 reserveEndTime) = ve.locked(reserveTokenId);
        if (unlockTime > mainEndTime) ve.increase_unlock_time(mainTokenId, MAX_LOCK);
        if (unlockTime > reserveEndTime) ve.increase_unlock_time(reserveTokenId, MAX_LOCK);
    }

    function _split(uint256[] memory _amounts, uint256 _tokenId) internal returns (uint256 tokenId0, uint256 tokenId1) {
        uint256 totalNftBefore = ve.balanceOf(address(this));
        ve.split(_amounts, _tokenId);
        uint256 totalNftAfter = ve.balanceOf(address(this));
        require(totalNftAfter == totalNftBefore + 1, "Proxy: SPLIT_NFT_FAILED");
        
        tokenId1 = ve.tokenOfOwnerByIndex(address(this), totalNftAfter - 1);
        tokenId0 = ve.tokenOfOwnerByIndex(address(this), totalNftAfter - 2);
    }

    function splitWithdraw(uint256 _amount) external onlyCpCHR returns (uint256) {
        uint256[] memory _amounts = new uint256[](2);
        _amounts[0] = _amount;
        _amounts[1] = withdrawableBalance() - _amount;
        (uint256 tokenIdForUser, uint256 tokenIdRemaining) = _split(_amounts, redeemTokenId);
        if (mainTokenId == redeemTokenId) {
            mainTokenId = tokenIdRemaining;
        } else {
            reserveTokenId = tokenIdRemaining;
        }

        redeemTokenId = tokenIdRemaining;
        ve.transferFrom(address(this), msg.sender, tokenIdForUser);
        return tokenIdForUser;
    }

    function split(uint256 _amount) external onlyOwner {
        require(mainTokenId > 0 && reserveTokenId > 0, "CpCHR: NOT_ASSIGNED");
        uint256 totalMainAmount = balanceOfWantInMainVe();
        uint256 reserveAmount = balanceOfWantInReserveVe();
        require(_amount < totalMainAmount - MAX_RATE, "CpCHR: INSUFFICIENCY_AMOUNT_OUT");
        if (_amount > 0) {
            uint256[] memory _amounts = new uint256[](2);
            _amounts[0] = _amount;
            _amounts[1] = totalMainAmount - _amount;
            (uint256 tokenIdToMergeReserve, uint256 newMainTokenId) = _split(_amounts, mainTokenId);
            if (redeemTokenId == mainTokenId) {
                redeemTokenId = newMainTokenId;
            }

            mainTokenId = newMainTokenId;
            ve.merge(tokenIdToMergeReserve, reserveTokenId);
            require(balanceOfWantInReserveVe() == reserveAmount + _amount, "CpCHR: SPLIT_ERROR");
        }
    }

    function setRedeemTokenId(uint256 _tokenId) external onlyOwner {
        require(_tokenId == mainTokenId || _tokenId == reserveTokenId, "Proxy: NOT_ASSIGNED_TOKEN");
        emit SetRedeemTokenId(redeemTokenId, _tokenId);
        redeemTokenId = _tokenId;
    }

    function withdrawableBalance() public view returns (uint256 wants) {
        (wants, ) = ve.locked(redeemTokenId);
    }

    function balanceOfWantInMainVe() public view returns (uint256 wants) {
        (wants, ) = ve.locked(mainTokenId);
    }

    function balanceOfWantInReserveVe() public view returns (uint256 wants) {
        (wants, ) = ve.locked(reserveTokenId);
    }

    function resetVote(uint256 _tokenId) external onlyCpCHR {
        solidVoter.reset(_tokenId);
    }

    function approveVe(address _approved, uint _tokenId) external onlyOwner {
        ve.approve(_approved, _tokenId);
    }

    function release(uint256 _tokenId) external onlyCpCHR {
        uint256 before = CHR.balanceOf(address(this));
        ve.withdraw(mainTokenId);
        uint256 amount = CHR.balanceOf(address(this)) - before;
        if (amount > 0) CHR.safeTransfer(cpCHR, amount);
        if (_tokenId == mainTokenId) mainTokenId = 0;
        if (_tokenId == reserveTokenId) reserveTokenId = 0;
    }

    function whitelist(uint256 _tokenId, address _token) external onlyOwner {
        solidVoter.whitelist(_token, _tokenId);
    }

    function locked(uint256 _tokenId) external view returns (uint256 amount, uint256 endTime) {
        return ve.locked(_tokenId);
    }

    // function claimVeEmissions() external onlyCpCHR returns (uint256) {
    //     uint256 reward = veDist.claim(mainTokenId);
    //     if (reserveTokenId > 0) {
    //         reward = reward + veDist.claim(reserveTokenId);
    //     }
        
    //     return reward;
    // }

    // Voting
    function vote(
        uint256 _tokenId,
        address[] calldata _tokenVote,
        uint256[] calldata _weights
    ) external onlyCpCHR {
        solidVoter.vote(_tokenId, _tokenVote, _weights);
    }

    // Add gauge
    function addGauge(address _lp, address[] calldata _bribeTokens, address[] calldata _feeTokens) external onlyOwner {
        address gauge = solidVoter.gauges(_lp);
        gauges[_lp] = Gauges(solidVoter.external_bribes(gauge), solidVoter.internal_bribes(gauge), _bribeTokens, _feeTokens);
        lpInitialized[_lp] = true;
        emit AddedGauge(solidVoter.external_bribes(gauge), solidVoter.internal_bribes(gauge), _bribeTokens, _feeTokens);
    }

    // Delete a reward token
    function deleteRewardToken(address _token) external onlyOwner {
        delete routes[_token];
    }

    // Add multiple reward tokens
    function addMultipleRewardTokens(
        ISolidlyRouter.Routes[][] calldata _routes
    ) external onlyOwner {
        for (uint256 i; i < _routes.length; i++) {
            addRewardToken(_routes[i]);
        }
    }

    // Add a reward token
    function addRewardToken(
        ISolidlyRouter.Routes[] calldata _route
    ) public onlyOwner {
        address _rewardToken = _route[0].from;
        require(_rewardToken != address(CHR), "Proxy: ROUTE_FROM_IS_CHR");
        require(
            _route[_route.length - 1].to == address(CHR),
            "Proxy: ROUTE_TO_NOT_CHR"
        );
        for (uint256 i; i < _route.length; i++) {
            routes[_rewardToken].push(_route[i]);
        }
        IERC20Upgradeable(_rewardToken).approve(address(router), type(uint256).max);
        emit AddedRewardToken(_rewardToken);
    }

    function setSolidVoter(address _solidVoter) external onlyCpCHR {
        emit SetSolidVoter(address(solidVoter), _solidVoter);
        solidVoter = IVoter(_solidVoter);
    }

    // function setVeDist(address _veDist) external onlyCpCHR {
    //     emit SetVeDist(address(veDist), _veDist);
    //     veDist = IVeDist(_veDist);
    // }

    function setExtension(address _extension) external onlyOwner {
        extension = _extension;
    }

    function externalCall(address _target, bytes calldata _calldata) external payable onlyExtension returns (bool _success, bytes memory _result) {
        require(extension != address(0));
        return _target.call{value: msg.value}(_calldata);
    }

    function getBribeReward(uint256 _tokenId, address _lp) external onlyCpCHR {
        Gauges memory _gauges = gauges[_lp];
        ISolidlyGauge(_gauges.bribeGauge).getReward(_tokenId, _gauges.bribeTokens);

        for (uint256 i; i < _gauges.bribeTokens.length; ++i) {
            address bribeToken = _gauges.bribeTokens[i];
            uint256 tokenBal = IERC20Upgradeable(bribeToken).balanceOf(address(this));
            if (tokenBal > 0) {
                if (bribeToken == address(CHR) || bribeToken == address(cpCHR)) {
                    IERC20Upgradeable(bribeToken).safeTransfer(cpCHR, tokenBal);
                } else {
                    router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                        tokenBal,
                        0,
                        routes[bribeToken],
                        address(cpCHR),
                        block.timestamp
                    );
                }
            }
        }
    }

    function getTradingFeeReward(uint256 _tokenId, address _lp) external onlyCpCHR {
        Gauges memory _gauges = gauges[_lp];
        ISolidlyGauge(_gauges.feeGauge).getReward(_tokenId, _gauges.feeTokens);

        for (uint256 i; i < _gauges.feeTokens.length; ++i) {
            address feeToken = _gauges.feeTokens[i];
            uint256 tokenBal = IERC20Upgradeable(feeToken).balanceOf(address(this));
            if (tokenBal > 0) {
                if (feeToken == address(CHR) || feeToken == address(cpCHR)) {
                    IERC20Upgradeable(feeToken).safeTransfer(cpCHR, tokenBal);
                } else {
                    router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                        tokenBal,
                        0,
                        routes[feeToken],
                        address(cpCHR),
                        block.timestamp
                    );
                }
            }
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface IMinter {
    function controller() external view returns (address);
    function updatePeriod() external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface ISolidlyGauge {
    function getReward(uint256 tokenId, address[] memory rewards) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface ISolidlyRouter {
    // Routes
    struct Routes {
        address from;
        address to;
        bool stable;
    }

    function wETH() external view returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        bool stable, 
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable, 
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETH(
        address token,
        bool stable,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function swapExactTokensForTokensSimple(
        uint amountIn, 
        uint amountOutMin, 
        address tokenFrom, 
        address tokenTo,
        bool stable, 
        address to, 
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForTokens(
        uint amountIn, 
        uint amountOutMin, 
        Routes[] memory route, 
        address to, 
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external view returns (uint amount, bool stable);

    function getAmountsOut(uint amountIn, Routes[] memory routes) external view returns (uint[] memory amounts);

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired
    ) external view returns (uint amountA, uint amountB, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        Routes[] calldata routes,
        address to,
        uint deadline
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface IVeDist {
    function claim(uint256 tokenId) external returns (uint);
    function claimable(uint _tokenId) external view returns (uint);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface IVeToken {
    function create_lock(uint256 _value, uint256 _lockDuration) external returns (uint256 _tokenId);
    function increase_amount(uint256 tokenId, uint256 value) external;
    function increase_unlock_time(uint256 tokenId, uint256 duration) external;
    function withdraw(uint256 tokenId) external;
    function balanceOfNFT(uint256 tokenId) external view returns (uint256 balance);
    function locked(uint256 tokenId) external view returns (uint256 amount, uint256 endTime);
    function token() external view returns (address);
    function merge(uint _from, uint _to) external;
    function transferFrom(address _from, address _to, uint _tokenId) external;
    function balanceOf(address _owner) external view returns (uint);
    function split(uint[] memory amounts, uint _tokenId) external;
    function tokenOfOwnerByIndex(address _owner, uint _tokenIndex) external view returns (uint);
    function approve(address _approved, uint _tokenId) external;
    function voted(uint _tokenId) external view returns (bool);
    function ownerOf(uint256 _tokenId) external view returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface IVoter {
    function vote(uint256 tokenId, address[] calldata poolVote, uint256[] calldata weights) external;
    function whitelist(address token, uint256 tokenId) external;
    function reset(uint256 tokenId) external;
    function gauges(address lp) external view returns (address);
    function _ve() external view returns (address);
    function minter() external view returns (address);
    function external_bribes(address _lp) external view returns (address);
    function internal_bribes(address _lp) external view returns (address);
    function votes(uint256 id, address lp) external view returns (uint256);
    function poolVote(uint256 id, uint256 index) external view returns (address);
    function lastVoted(uint256 id) external view returns (uint256);
    function weights(address lp) external view returns (uint256);
    function factory() external view returns (address);
}