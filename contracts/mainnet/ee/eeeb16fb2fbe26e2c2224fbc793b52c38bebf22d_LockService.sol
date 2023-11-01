/**
 *Submitted for verification at Arbiscan.io on 2023-10-31
*/

// solhint-disable reason-string
// solhint-disable contract-name-camelcase
pragma solidity 0.4.16;

/**
 * Token contract functions
 */
contract Token {
  function balanceOf(address who) external view returns (uint256);

  function allowance(address owner, address spender) external view returns (uint256);

  function transfer(address to, uint256 value) external returns (bool);

  function approve(address spender, uint256 value) external returns (bool);

  function approveAndCall(
    address spender,
    uint tokens,
    bytes data
  ) external returns (bool success);

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool);
}

library SafeMath {
  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    require(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    require(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    require(c >= a);
    return c;
  }

  function ceil(uint256 a, uint256 m) internal constant returns (uint256) {
    uint256 c = add(a, m);
    uint256 d = sub(c, 1);
    return mul(div(d, m), m);
  }
}

contract Ownable {
  address public owner;

  function Ownable() internal {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  function transferOwnership(address newOwner) external onlyOwner {
    owner = newOwner;
  }
}

contract LockService is Ownable {
  using SafeMath for uint256;

  /*
   * Deposit vars
   */
  struct Items {
    address tokenAddress;
    address withdrawalAddress;
    uint256 tokenAmount;
    uint256 unlockTime;
    bool withdrawn;
  }

  uint256 public depositId;
  uint256[] public allDepositIds;
  mapping(address => uint256[]) public depositsByWithdrawalAddress;
  mapping(uint256 => Items) public lockedToken;
  mapping(address => mapping(address => uint256)) public walletTokenBalance;

  event LogWithdrawal(address SentToAddress, uint256 AmountTransferred);

  /**
   * Lock tokens
   */
  function lockTokens(
    address _tokenAddress,
    address _withdrawalAddress,
    uint256 _amount,
    uint256 _unlockTime
  ) external returns (uint256 _id) {
    require(_amount > 0);
    require(_unlockTime < 10000000000);

    // Update balance in address
    walletTokenBalance[_tokenAddress][_withdrawalAddress] = walletTokenBalance[_tokenAddress][_withdrawalAddress].add(
      _amount
    );

    _id = ++depositId;
    lockedToken[_id].tokenAddress = _tokenAddress;
    lockedToken[_id].withdrawalAddress = _withdrawalAddress;
    lockedToken[_id].tokenAmount = _amount;
    lockedToken[_id].unlockTime = _unlockTime;
    lockedToken[_id].withdrawn = false;

    allDepositIds.push(_id);
    depositsByWithdrawalAddress[_withdrawalAddress].push(_id);

    // Transfer tokens into contract
    require(Token(_tokenAddress).transferFrom(msg.sender, this, _amount));
  }

  /**
   * Create multiple locks
   */
  function createMultipleLocks(
    address _tokenAddress,
    address _withdrawalAddress,
    uint256[] _amounts,
    uint256[] _unlockTimes
  ) external {
    require(_amounts.length > 0);
    require(_amounts.length == _unlockTimes.length);

    uint256 i;
    for (i = 0; i < _amounts.length; i++) {
      require(_amounts[i] > 0);
      require(_unlockTimes[i] < 10000000000);

      // Update balance in address
      walletTokenBalance[_tokenAddress][_withdrawalAddress] = walletTokenBalance[_tokenAddress][_withdrawalAddress].add(
        _amounts[i]
      );

      uint256 _id = ++depositId;
      lockedToken[_id].tokenAddress = _tokenAddress;
      lockedToken[_id].withdrawalAddress = _withdrawalAddress;
      lockedToken[_id].tokenAmount = _amounts[i];
      lockedToken[_id].unlockTime = _unlockTimes[i];
      lockedToken[_id].withdrawn = false;

      allDepositIds.push(_id);
      depositsByWithdrawalAddress[_withdrawalAddress].push(_id);

      // Transfer tokens into contract
      require(Token(_tokenAddress).transferFrom(msg.sender, this, _amounts[i]));
    }
  }

  /**
   * Extend lock Duration
   */
  function extendLockDuration(uint256 _id, uint256 _unlockTime) external {
    require(_unlockTime < 10000000000);
    require(_unlockTime > lockedToken[_id].unlockTime);
    require(!lockedToken[_id].withdrawn);
    require(msg.sender == lockedToken[_id].withdrawalAddress);

    // Set new unlock time
    lockedToken[_id].unlockTime = _unlockTime;
  }

  /**
   * Transfer locked tokens
   */
  function transferLocks(uint256 _id, address _receiverAddress) external {
    require(!lockedToken[_id].withdrawn);
    require(msg.sender == lockedToken[_id].withdrawalAddress);

    // Decrease sender's token balance
    walletTokenBalance[lockedToken[_id].tokenAddress][msg.sender] = walletTokenBalance[lockedToken[_id].tokenAddress][
      msg.sender
    ].sub(lockedToken[_id].tokenAmount);

    // Increase receiver's token balance
    walletTokenBalance[lockedToken[_id].tokenAddress][_receiverAddress] = walletTokenBalance[
      lockedToken[_id].tokenAddress
    ][_receiverAddress].add(lockedToken[_id].tokenAmount);

    // Remove this id from sender address
    uint256 j;
    uint256 arrLength = depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress].length;
    for (j = 0; j < arrLength; j++) {
      if (depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress][j] == _id) {
        depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress][j] = depositsByWithdrawalAddress[
          lockedToken[_id].withdrawalAddress
        ][arrLength - 1];
        depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress].length--;
        break;
      }
    }

    // Assign this id to receiver address
    lockedToken[_id].withdrawalAddress = _receiverAddress;
    depositsByWithdrawalAddress[_receiverAddress].push(_id);
  }

  /**
   * Withdraw tokens
   */
  function withdrawTokens(uint256 _id) external {
    require(block.timestamp >= lockedToken[_id].unlockTime);
    require(msg.sender == lockedToken[_id].withdrawalAddress);
    require(!lockedToken[_id].withdrawn);

    lockedToken[_id].withdrawn = true;

    // Update balance in address
    walletTokenBalance[lockedToken[_id].tokenAddress][msg.sender] = walletTokenBalance[lockedToken[_id].tokenAddress][
      msg.sender
    ].sub(lockedToken[_id].tokenAmount);

    // Remove this id from this address
    uint256 j;
    uint256 arrLength = depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress].length;
    for (j = 0; j < arrLength; j++) {
      if (depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress][j] == _id) {
        depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress][j] = depositsByWithdrawalAddress[
          lockedToken[_id].withdrawalAddress
        ][arrLength - 1];
        depositsByWithdrawalAddress[lockedToken[_id].withdrawalAddress].length--;
        break;
      }
    }

    // Transfer tokens to wallet address
    require(Token(lockedToken[_id].tokenAddress).transfer(msg.sender, lockedToken[_id].tokenAmount));
    LogWithdrawal(msg.sender, lockedToken[_id].tokenAmount);
  }

  /* Get total token balance in contract */
  function getTotalTokenBalance(address _tokenAddress) external view returns (uint256) {
    return Token(_tokenAddress).balanceOf(this);
  }

  /* Get total token balance by address */
  function getTokenBalanceByAddress(address _tokenAddress, address _walletAddress) external view returns (uint256) {
    return walletTokenBalance[_tokenAddress][_walletAddress];
  }

  /* Get allDepositIds */
  function getAllDepositIds() external view returns (uint256[]) {
    return allDepositIds;
  }

  /* Get getDepositDetails */
  function getDepositDetails(uint256 _id)
    external
    view
    returns (
      address _tokenAddress,
      address _withdrawalAddress,
      uint256 _tokenAmount,
      uint256 _unlockTime,
      bool _withdrawn
    )
  {
    return (
      lockedToken[_id].tokenAddress,
      lockedToken[_id].withdrawalAddress,
      lockedToken[_id].tokenAmount,
      lockedToken[_id].unlockTime,
      lockedToken[_id].withdrawn
    );
  }

  /* Get DepositsByWithdrawalAddress */
  function getDepositsByWithdrawalAddress(address _withdrawalAddress) external view returns (uint256[]) {
    return depositsByWithdrawalAddress[_withdrawalAddress];
  }
}