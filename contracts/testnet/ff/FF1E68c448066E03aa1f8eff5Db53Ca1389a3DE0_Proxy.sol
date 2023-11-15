// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./container/BaseContainer.sol";
import "./modules/LoanManager.sol";
import "./database/HeartToken.sol";
import "./modules/Wallet.sol";

contract Proxy is BaseContainer {
    function postRequest(uint256 _amount) external {
        bytes32 _debtNo = (sha256(abi.encodePacked(msg.sender, now)));
        LoanManager(getAddressOfLoanManager()).requestLoan(
            _debtNo,
            msg.sender,
            _amount
        );
    }

    function lendLoan(bytes32 _debtNo) external payable{
        LoanManager(getAddressOfLoanManager()).lendLoan.value(msg.value)(
            _debtNo,
            msg.sender
        );
    }

    function payLoan(bytes32 _debtNo) external payable{
        LoanManager(getAddressOfLoanManager()).payLoan.value(msg.value)(
            _debtNo,
            msg.sender
        );
    }

    function burnToken(uint256 _amount) external {
        HeartToken(payable(getAddressOfHeartToken())).removeToken(msg.sender, _amount);
    }

    function withDraw(uint256 _amount) external {
        Wallet(getAddressOfWallet()).withdraw(msg.sender,_amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

/** 
    @title Owned
    @dev allows for ownership transfer and a contract that inherits from it.
    @author abhaydeshpande
*/

contract Owned {
    address payable public owner;

    constructor() public {
        owner = payable(msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    function transferOwnership(address payable newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner address cannot be zero");
        owner = newOwner;
    }
}

contract MyContract is Owned {
    fallback() external payable {
        revert("Invalid transaction");
    }

    receive() external payable {
        owner.transfer(msg.value);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./ContractManager.sol";
import "./ContractNames.sol";


/**
    @title BaseContainer
    @dev Contains all getters of contract addresses in the system
    @author abhaydeshpande
 */
contract BaseContainer is ContractManager, ContractNames {
    function getAddressOfLoanManager() public view returns (address) {
        return getContract(CONTRACT_LOAN_MANAGER);
    }

    function getAddressOfWallet() public view returns (address) {
        return getContract(CONTRACT_WALLET);
    }

    function getAddressOfLoanDB() public view returns (address) {
        return getContract(CONTRACT_LOAN_DB);
    }

    function getAddressOfHeartToken() public view returns (address) {
        return getContract(CONTRACT_HEART_TOKEN);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../auth/Owned.sol";
import "./ContractNames.sol";
import "./BaseContainer.sol";


/**
    @title Contained
    @dev Wraps the contracts and functions from unauthorized access outside the system
    @author abhaydeshpande
 */
contract Contained is Owned, ContractNames {
    BaseContainer public container;

    function setContainerEntry(BaseContainer _container) public onlyOwner {
        container = _container;
    }

    modifier onlyContained() {
        require(address(container) != address(0), "No Container");
        require(msg.sender == address(container), "Only through Container");
        _;
    }

    modifier onlyContract(string memory name) {
        require(address(container) != address(0), "No Container");
        address allowedContract = container.getContract(name);
        require(allowedContract != address(0), "Invalid contract name");
        require(
            msg.sender == allowedContract,
            "Only specific contract can access"
        );
        _;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../auth/Owned.sol";


/**
    @title ContractManager
    @dev Manages all the contract in the system
    @author abhaydeshpande
 */
contract ContractManager is Owned {
    mapping(string => address) private contracts;

    function addContract(string memory name, address contractAddress)
        public
        onlyOwner
    {
        require(contracts[name] == address(0), "Contract already exists");
        contracts[name] = contractAddress;
    }

    function getContract(string memory name) public view returns (address) {
        require(contracts[name] != address(0), "Contract hasn't set yet");
        return contracts[name];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

/**
    @title ContractNames
    @dev defines constant strings representing the names of other contracts in the system.
    @author abhaydeshpande
 */
contract ContractNames {
    string constant CONTRACT_LOAN_MANAGER = "LoanManager";
    string constant CONTRACT_WALLET = "Wallet";
    string constant CONTRACT_LOAN_DB = "LoanDB";
    string constant CONTRACT_HEART_TOKEN = "HeartToken";
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../lib/ERC20.sol";
import "../container/Contained.sol";

/**
    @title HeartToken
    @dev defines an ERC20 token to mint tokens and burn tokens
    @author abhaydeshpande
 */

contract HeartToken is ERC20, Contained {
    string private _name;
    uint8 private _decimals;
    string private _symbol;

    constructor() public {
        _name = "Heart Token"; // Set the name for display purposes
        _decimals = 0; // Amount of decimals for display purposes
        _symbol = "HEART"; // Set the symbol for display purposes
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function getToken(address buyer, uint256 value)
        external
        onlyContract(CONTRACT_LOAN_MANAGER)
    {
        require(buyer != address(0), "Invalid address");
        require(value > 0, "Invalid value");
        _mint(buyer, value);
    }

    function removeToken(address remover, uint256 value)
        external
        onlyContained()
    {
        require(remover != address(0), "Invalid address");
        require(value > 0, "Invalid value");
        require(balanceOf(remover) >= value, "Not enough token to burn");
        _burn(remover, value);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../lib/SafeMath.sol";
import "../container/Contained.sol";

/**
    @title LoanDB
    @dev Stores all the loan details.
    @author abhaydeshpande
 */
contract LoanDB is Contained {
    using SafeMath for uint256;
    enum LoanState {
    REQUESTED,
    FUNDED,
    PAID
}

struct Debt {
    address lender;
    address borrower;
    uint256 amountOfDebt;
    uint256 interest;
    uint8 loanState;
}

mapping(bytes32 => Debt) private debtInfo;
mapping(address => bytes32[]) private debtHistory;
mapping(address => bytes32[]) private lendHistory;
mapping(address => bool) private haveDebt;

function addDebt(
    bytes32 debtNo,
    address borrower,
    uint256 amountOfDebt,
    uint256 interest
) external onlyContract(CONTRACT_LOAN_MANAGER) {
    require(amountOfDebt > 0, "Invalid debt amount");
    require(interest > 0, "Invalid interest rate");

    Debt storage newDebt = debtInfo[debtNo];
    require(newDebt.amountOfDebt == 0, "Debt already exists");

    newDebt.borrower = borrower;
    newDebt.amountOfDebt = amountOfDebt;
    newDebt.interest = interest;
    newDebt.loanState = uint8(LoanState.REQUESTED);

    debtHistory[borrower].push(debtNo);
}

function updateLender(bytes32 debtNo, address lender)
    external
    onlyContract(CONTRACT_LOAN_MANAGER)
{
    require(lender != address(0), "Invalid lender address");

    Debt storage updatedDebt = debtInfo[debtNo];
    require(updatedDebt.amountOfDebt > 0, "Debt does not exist");
    require(
        updatedDebt.lender == address(0),
        "Lender is already assigned"
    );

    updatedDebt.lender = lender;
    updatedDebt.loanState = uint8(LoanState.FUNDED);

    lendHistory[lender].push(debtNo);
}

function completeDebt(bytes32 debtNo)
    external
    onlyContract(CONTRACT_LOAN_MANAGER)
{
    Debt storage completedDebt = debtInfo[debtNo];
    require(completedDebt.amountOfDebt > 0, "Debt does not exist");

    completedDebt.loanState = uint8(LoanState.PAID);
}

function setHaveDebt(address sender, bool state)
    external
    onlyContract(CONTRACT_LOAN_MANAGER)
{
    haveDebt[sender] = state;
}

function checkHaveDebt(address sender) external view returns (bool) {
    return haveDebt[sender];
}

function getLenderofDebt(bytes32 debtNo) external view returns (address) {
    return debtInfo[debtNo].lender;
}

function getBorrowerofDebt(bytes32 debtNo) external view returns (address) {
    return debtInfo[debtNo].borrower;
}

function getAmountofDebt(bytes32 debtNo) external view returns (uint256) {
    return debtInfo[debtNo].amountOfDebt;
}

function getInterestofDebt(bytes32 debtNo) external view returns (uint256) {
    return debtInfo[debtNo].interest;
}

function getStateofDebt(bytes32 debtNo) external view returns (uint8) {
    return debtInfo[debtNo].loanState;
}

function getDebtHistory(address _address)
    external
    view
    returns (bytes32[] memory)
{
    require(msg.sender == _address || msg.sender == owner, "Unauthorized access");

    return debtHistory[_address];
}

function getLendHistory(address _address)
    external
    view
    returns (bytes32[] memory)
{
    require(msg.sender == _address || msg.sender == owner, "Unauthorized access");

    return lendHistory[_address];
}}

// SPDX-License-Identifier: MIT
pragma solidity 0.6.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * IMPORTANT: It is unsafe to assume that an address for which this
     * function returns false is an externally-owned account (EOA) and not a
     * contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // "assembly" keyword is used to call low-level functions in Solidity
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
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
        (bool success, ) = recipient.call.value( amount)("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./IERC20.sol";
import "./SafeMath.sol";
import "./Address.sol";


/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20MinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is IERC20 {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

   

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender)
        public
        override
        view
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            msg.sender,
            _allowances[sender][msg.sender].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender].add(addedValue)
        );
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount)
        internal
        virtual
    {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(
            amount,
            "ERC20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        _balances[account] = _balances[account].sub(
            amount,
            "ERC20: burn amount exceeds balance"
        );
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount)
        internal
        virtual
    {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * Requirements:
     *
     * - this function can only be called from a constructor.
     */
    // function _setupDecimals(uint8 decimals_) internal {
    //     require(
    //         !address(this).isContract(),
    //         "ERC20: decimals cannot be changed after construction"
    //     );
    //     _decimals = decimals_;
    // }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:using-hooks.adoc[Using Hooks].
     */
    // function _beforeTokenTransfer(address from, address to, uint256 amount)
    //     internal
    //     virtual
    // {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;


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
    function transferFrom(address sender, address recipient, uint256 amount)
        external
        returns (bool);

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

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;


/**
 * @dev provides arithmetic functions with overflow/underflow protection.
 */
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage)
        internal
        pure
        returns (uint256)
    {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage)
        internal
        pure
        returns (uint256)
    {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage)
        internal
        pure
        returns (uint256)
    {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../lib/SafeMath.sol";
import "../database/LoanDB.sol";
import "../database/HeartToken.sol";
import "../container/Contained.sol";
import "./Wallet.sol";


/**
    @title LoanManager
    @dev manages the lending and repayment of loans, and rewards users with HeartToken for participating.
    @author abhaydeshpande
 */
contract LoanManager is Contained {
    using SafeMath for uint256;
    enum LoanState {REQUESTED, FUNDED, PAID}
    event Requested(bytes32 debtNo, address _owner, uint256 _amount);
    event Funded(bytes32 debtNo, address _lender);
    event PaidBack(bytes32 debtNo);
    uint104 rewardToken = 10;
    LoanDB loandb;
    HeartToken heartToken;
    Wallet wallet;

    function init() external onlyOwner {
        loandb = LoanDB(container.getContract(CONTRACT_LOAN_DB));
        heartToken = HeartToken(payable(container.getContract(CONTRACT_HEART_TOKEN)));
        wallet = Wallet(container.getContract(CONTRACT_WALLET));
    }

    function setRewardToken(uint104 _amount) external onlyOwner {
        rewardToken = _amount;
    }

    function requestLoan(bytes32 _debtNo, address _borrower, uint256 _amount)
        external
        onlyContained
    {
        require(_amount >= 1e16 wei, "The amount is too small to borrow");
        require(loandb.getBorrowerofDebt(_debtNo) == address(0), "debt exists");
        require(loandb.checkHaveDebt(_borrower) == false,"already have Debt");
        uint256 _interest = (_amount.mul(2)).div(100);
        loandb.addDebt(_debtNo, _borrower, _amount, _interest);
        emit Requested(_debtNo, _borrower, _amount);
    }

    function lendLoan(bytes32 _debtNo, address _sender)
        external
        payable
        onlyContained
    {
        uint256 _amount = loandb.getAmountofDebt(_debtNo);
        address _borrower = loandb.getBorrowerofDebt(_debtNo);
        require(loandb.getStateofDebt(_debtNo) == uint(LoanState.REQUESTED),"Not in requested state");
        require(msg.value >= _amount, "Not enough amount");
        require(_borrower != address(0), "Debt is not existing");
        require(loandb.checkHaveDebt(_borrower) == false,"already have Debt");
        wallet.deposit.value(msg.value)(_borrower);
        loandb.updateLender(_debtNo, _sender);
        loandb.setHaveDebt(_borrower,true);
        heartToken.getToken(_sender, rewardToken);
        emit Funded(_debtNo, _sender);
    }

    function payLoan(bytes32 _debtNo, address _sender)
        external
        payable
        onlyContained
    {
        uint256 _amount = loandb.getAmountofDebt(_debtNo).add(
            loandb.getInterestofDebt(_debtNo)
        );
        require(msg.value >= _amount, "Not enough amount");
        require(_amount != 0, "Debt is not existing");
        require(loandb.getStateofDebt(_debtNo) == uint(LoanState.FUNDED),"Not in funded state");
        address _lender = loandb.getLenderofDebt(_debtNo);
        require(_lender != address(0), "Does not have lender");
        wallet.deposit.value(msg.value)(_lender);
        loandb.completeDebt(_debtNo);
        heartToken.getToken(_sender, rewardToken);
        loandb.setHaveDebt(_sender,false);
        emit PaidBack(_debtNo);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../lib/SafeMath.sol";
import "../container/Contained.sol";


/**
    @title Wallet
    @dev All of amount of money for funds and pay back is stored here.
    @author abhaydeshpande
 */

contract Wallet is Contained {
    using SafeMath for uint256;
    event Deposited(address indexed payee, uint256 weiAmount);
    event Withdrawn(address indexed payee, uint256 weiAmount);
    mapping(address => uint256) private _deposits;

    function depositsOf(address payee) public view returns (uint256) {
        return _deposits[payee];
    }

    /**
     * @dev Stores the sent amount as credit to be withdrawn.
     * @param payee The destination address of the funds.
     */
    function deposit(address payee)
        public
        payable
        onlyContract(CONTRACT_LOAN_MANAGER)
    {
        uint256 amount = msg.value;
        _deposits[payee] = _deposits[payee].add(amount);

        emit Deposited(payee, amount);
    }

    /**
     * @dev Withdraw accumulated balance for a payee.
     * @param payee The address whose funds will be withdrawn and transferred to.
     */
    function withdraw(address payable payee, uint256 payment)
        public
        onlyContained
    {
        _deposits[payee] = _deposits[payee].sub(payment);

        payee.transfer(payment);

        emit Withdrawn(payee, payment);
    }
}
