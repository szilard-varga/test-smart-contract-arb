/**
 *Submitted for verification at Arbiscan on 2023-01-31
*/

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.16;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}

abstract contract Ownable {
    error Ownable_NotOwner();
    error Ownable_NewOwnerZeroAddress();

    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /// @dev Returns the address of the current owner.
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /// @dev Throws if called by any account other than the owner.
    modifier onlyOwner() {
        if (owner() != msg.sender) revert Ownable_NotOwner();
        _;
    }

    /// @dev Transfers ownership of the contract to a new account (`newOwner`).
    /// Can only be called by the current owner.
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) revert Ownable_NewOwnerZeroAddress();
        _transferOwnership(newOwner);
    }

    /// @dev Transfers ownership of the contract to a new account (`newOwner`).
    /// Internal function without access restriction.
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = a * b
            // Compute the product mod 2**256 and mod 2**256 - 1
            // then use the Chinese Remainder Theorem to reconstruct
            // the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2**256 + prod0
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(a, b, not(0))
                prod0 := mul(a, b)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division
            if (prod1 == 0) {
                require(denominator > 0);
                assembly {
                    result := div(prod0, denominator)
                }
                return result;
            }

            // Make sure the result is less than 2**256.
            // Also prevents denominator == 0
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0]
            // Compute remainder using mulmod
            uint256 remainder;
            assembly {
                remainder := mulmod(a, b, denominator)
            }
            // Subtract 256 bit number from 512 bit number
            assembly {
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator
            // Compute largest power of two divisor of denominator.
            // Always >= 1.
            uint256 twos = (type(uint256).max - denominator + 1) & denominator;
            // Divide denominator by power of two
            assembly {
                denominator := div(denominator, twos)
            }

            // Divide [prod1 prod0] by the factors of two
            assembly {
                prod0 := div(prod0, twos)
            }
            // Shift in bits from prod1 into prod0. For this we need
            // to flip `twos` such that it is 2**256 / twos.
            // If twos is zero, then it becomes one
            assembly {
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;

            // Invert denominator mod 2**256
            // Now that denominator is an odd number, it has an inverse
            // modulo 2**256 such that denominator * inv = 1 mod 2**256.
            // Compute the inverse by starting with a seed that is correct
            // correct for four bits. That is, denominator * inv = 1 mod 2**4
            uint256 inv = (3 * denominator) ^ 2;
            // Now use Newton-Raphson iteration to improve the precision.
            // Thanks to Hensel's lifting lemma, this also works in modular
            // arithmetic, doubling the correct bits in each step.
            inv *= 2 - denominator * inv; // inverse mod 2**8
            inv *= 2 - denominator * inv; // inverse mod 2**16
            inv *= 2 - denominator * inv; // inverse mod 2**32
            inv *= 2 - denominator * inv; // inverse mod 2**64
            inv *= 2 - denominator * inv; // inverse mod 2**128
            inv *= 2 - denominator * inv; // inverse mod 2**256

            // Because the division is now exact we can divide by multiplying
            // with the modular inverse of denominator. This will give us the
            // correct result modulo 2**256. Since the precoditions guarantee
            // that the outcome is less than 2**256, this is the final result.
            // We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inv;
            return result;
        }
    }

    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        unchecked {
            if (mulmod(a, b, denominator) > 0) {
                require(result < type(uint256).max);
                result++;
            }
        }
    }
}

/// @title Multicall
/// @notice Enables calling multiple methods in a single call to the contract
abstract contract Multicall {
    function multicall(bytes[] calldata data)
        external
        payable
        returns (bytes[] memory results)
    {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
    }
}

/// @title Self Permit
/// @notice Functionality to call permit on any EIP-2612-compliant token for use in the route
/// @dev These functions are expected to be embedded in multicalls to allow EOAs to approve a contract and call a function
/// that requires an approval in a single transaction.
abstract contract SelfPermit {
    function selfPermit(
        ERC20 token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable {
        token.permit(msg.sender, address(this), value, deadline, v, r, s);
    }

    function selfPermitIfNecessary(
        ERC20 token,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        if (token.allowance(msg.sender, address(this)) < value)
            selfPermit(token, value, deadline, v, r, s);
    }
}

interface IERC20 {
  function totalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

  function allowance(address owner, address spender)
    external
    view
    returns (uint256);

  function approve(address spender, uint256 amount) external returns (bool);

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract FarmingPool is Multicall, SelfPermit, Ownable {
  /// -----------------------------------------------------------------------
  /// Errors
  /// -----------------------------------------------------------------------

  error Error_ZeroOwner();
  error Error_AlreadyInitialized();
  error Error_NotRewardDistributor();
  error Error_AmountTooLarge();

  /// -----------------------------------------------------------------------
  /// Events
  /// -----------------------------------------------------------------------

  event RewardAdded(uint256 reward);
  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);
  event RewardPaid(address indexed user, uint256 reward);

  /// -----------------------------------------------------------------------
  /// Constants
  /// -----------------------------------------------------------------------

  uint256 internal constant PRECISION = 1e30;

  /// -----------------------------------------------------------------------
  /// Storage variables
  /// -----------------------------------------------------------------------

  IERC20 public farmToken;

  uint64 public duration;
  /// @notice The last Unix timestamp (in seconds) when rewardPerTokenStored was updated
  uint64 public lastUpdateTime;
  /// @notice The Unix timestamp (in seconds) at which the current reward period ends
  uint64 public periodFinish;

  /// @notice The per-second rate at which rewardPerToken increases
  uint256 public rewardRate;
  /// @notice The last stored rewardPerToken value
  uint256 public rewardPerTokenStored;
  /// @notice The total tokens staked in the pool
  uint256 public totalSupply;

  /// @notice Tracks if an address can call notifyReward()
  mapping(address => bool) public isRewardDistributor;

  /// @notice The amount of tokens staked by an account
  mapping(address => uint256) public balanceOf;
  /// @notice The rewardPerToken value when an account last staked/withdrew/withdrew rewards
  mapping(address => uint256) public userRewardPerTokenPaid;
  /// @notice The earned() value when an account last staked/withdrew/withdrew rewards
  mapping(address => uint256) public rewards;

  constructor(address _farmToken, uint64 _duration) {
    farmToken = IERC20(_farmToken);
    duration = _duration; // 1 days = 86400
    _transferOwnership(msg.sender);
  }

  /// -----------------------------------------------------------------------
  /// User actions
  /// -----------------------------------------------------------------------

  /// @notice Stakes tokens in the pool to earn rewards
  /// @param amount The amount of tokens to stake
  function stake(uint256 amount) external {
    /// -----------------------------------------------------------------------
    /// Validation
    /// -----------------------------------------------------------------------

    if (amount == 0) {
      return;
    }

    /// -----------------------------------------------------------------------
    /// Storage loads
    /// -----------------------------------------------------------------------

    uint256 accountBalance = balanceOf[msg.sender];
    uint64 lastTimeRewardApplicable_ = lastTimeRewardApplicable();
    uint256 totalSupply_ = totalSupply;
    uint256 rewardPerToken_ = _rewardPerToken(
      totalSupply_,
      lastTimeRewardApplicable_,
      rewardRate
    );

    /// -----------------------------------------------------------------------
    /// State updates
    /// -----------------------------------------------------------------------

    // accrue rewards
    rewardPerTokenStored = rewardPerToken_;
    lastUpdateTime = lastTimeRewardApplicable_;
    rewards[msg.sender] = _earned(
      msg.sender,
      accountBalance,
      rewardPerToken_,
      rewards[msg.sender]
    );
    userRewardPerTokenPaid[msg.sender] = rewardPerToken_;

    // stake
    totalSupply = totalSupply_ + amount;
    balanceOf[msg.sender] = accountBalance + amount;

    /// -----------------------------------------------------------------------
    /// Effects
    /// -----------------------------------------------------------------------

    require(
      farmToken.transferFrom(msg.sender, address(this), amount),
      "Error: Transfer failed"
    );

    emit Staked(msg.sender, amount);
  }

  /// @notice Withdraws staked tokens from the pool
  /// @param amount The amount of tokens to withdraw
  function withdraw(uint256 amount) external {
    /// -----------------------------------------------------------------------
    /// Validation
    /// -----------------------------------------------------------------------

    if (amount == 0) {
      return;
    }

    /// -----------------------------------------------------------------------
    /// Storage loads
    /// -----------------------------------------------------------------------

    uint256 accountBalance = balanceOf[msg.sender];
    uint64 lastTimeRewardApplicable_ = lastTimeRewardApplicable();
    uint256 totalSupply_ = totalSupply;
    uint256 rewardPerToken_ = _rewardPerToken(
      totalSupply_,
      lastTimeRewardApplicable_,
      rewardRate
    );

    /// -----------------------------------------------------------------------
    /// State updates
    /// -----------------------------------------------------------------------

    // accrue rewards
    rewardPerTokenStored = rewardPerToken_;
    lastUpdateTime = lastTimeRewardApplicable_;
    rewards[msg.sender] = _earned(
      msg.sender,
      accountBalance,
      rewardPerToken_,
      rewards[msg.sender]
    );
    userRewardPerTokenPaid[msg.sender] = rewardPerToken_;

    // withdraw stake
    balanceOf[msg.sender] = accountBalance - amount;
    // total supply has 1:1 relationship with staked amounts
    // so can't ever underflow
    unchecked {
      totalSupply = totalSupply_ - amount;
    }

    /// -----------------------------------------------------------------------
    /// Effects
    /// -----------------------------------------------------------------------

    require(farmToken.transfer(msg.sender, amount), "Error: Transfer failed");

    emit Withdrawn(msg.sender, amount);
  }

  /// @notice Withdraws all staked tokens and earned rewards
  function exit() external {
    /// -----------------------------------------------------------------------
    /// Validation
    /// -----------------------------------------------------------------------

    uint256 accountBalance = balanceOf[msg.sender];

    /// -----------------------------------------------------------------------
    /// Storage loads
    /// -----------------------------------------------------------------------

    uint64 lastTimeRewardApplicable_ = lastTimeRewardApplicable();
    uint256 totalSupply_ = totalSupply;
    uint256 rewardPerToken_ = _rewardPerToken(
      totalSupply_,
      lastTimeRewardApplicable_,
      rewardRate
    );

    /// -----------------------------------------------------------------------
    /// State updates
    /// -----------------------------------------------------------------------

    // give rewards
    uint256 reward = _earned(
      msg.sender,
      accountBalance,
      rewardPerToken_,
      rewards[msg.sender]
    );
    if (reward > 0) {
      rewards[msg.sender] = 0;
    }

    // accrue rewards
    rewardPerTokenStored = rewardPerToken_;
    lastUpdateTime = lastTimeRewardApplicable_;
    userRewardPerTokenPaid[msg.sender] = rewardPerToken_;

    // withdraw stake
    balanceOf[msg.sender] = 0;
    // total supply has 1:1 relationship with staked amounts
    // so can't ever underflow
    unchecked {
      totalSupply = totalSupply_ - accountBalance;
    }

    /// -----------------------------------------------------------------------
    /// Effects
    /// -----------------------------------------------------------------------

    // transfer stake
    require(
      farmToken.transfer(msg.sender, accountBalance),
      "Error: Transfer failed"
    );
    emit Withdrawn(msg.sender, accountBalance);

    // transfer rewards
    if (reward > 0) {
      require(farmToken.transfer(msg.sender, reward), "Error: Transfer failed");
      emit RewardPaid(msg.sender, reward);
    }
  }

  /// @notice Withdraws all earned rewards
  function getReward() external {
    /// -----------------------------------------------------------------------
    /// Storage loads
    /// -----------------------------------------------------------------------

    uint256 accountBalance = balanceOf[msg.sender];
    uint64 lastTimeRewardApplicable_ = lastTimeRewardApplicable();
    uint256 totalSupply_ = totalSupply;
    uint256 rewardPerToken_ = _rewardPerToken(
      totalSupply_,
      lastTimeRewardApplicable_,
      rewardRate
    );

    /// -----------------------------------------------------------------------
    /// State updates
    /// -----------------------------------------------------------------------

    uint256 reward = _earned(
      msg.sender,
      accountBalance,
      rewardPerToken_,
      rewards[msg.sender]
    );

    // accrue rewards
    rewardPerTokenStored = rewardPerToken_;
    lastUpdateTime = lastTimeRewardApplicable_;
    userRewardPerTokenPaid[msg.sender] = rewardPerToken_;

    // withdraw rewards
    if (reward > 0) {
      rewards[msg.sender] = 0;

      /// -----------------------------------------------------------------------
      /// Effects
      /// -----------------------------------------------------------------------

      require(farmToken.transfer(msg.sender, reward), "Error: Transfer failed");
      emit RewardPaid(msg.sender, reward);
    }
  }

  /// -----------------------------------------------------------------------
  /// Getters
  /// -----------------------------------------------------------------------

  /// @notice The latest time at which stakers are earning rewards.
  function lastTimeRewardApplicable() public view returns (uint64) {
    return
      block.timestamp < periodFinish ? uint64(block.timestamp) : periodFinish;
  }

  /// @notice The amount of reward tokens each staked token has earned so far
  function rewardPerToken() external view returns (uint256) {
    return _rewardPerToken(totalSupply, lastTimeRewardApplicable(), rewardRate);
  }

  /// @notice The amount of reward tokens an account has accrued so far. Does not
  /// include already withdrawn rewards.
  function earned(address account) external view returns (uint256) {
    return
      _earned(
        account,
        balanceOf[account],
        _rewardPerToken(totalSupply, lastTimeRewardApplicable(), rewardRate),
        rewards[account]
      );
  }

  /// -----------------------------------------------------------------------
  /// Owner actions
  /// -----------------------------------------------------------------------

  /// @notice Lets a reward distributor start a new reward period. The reward tokens must have already
  /// been transferred to this contract before calling this function. If it is called
  /// when a reward period is still active, a new reward period will begin from the time
  /// of calling this function, using the leftover rewards from the old reward period plus
  /// the newly sent rewards as the reward.
  /// @dev If the reward amount will cause an overflow when computing rewardPerToken, then
  /// this function will revert.
  /// @param reward The amount of reward tokens to use in the new reward period.
  function notifyRewardAmount(uint256 reward) external {
    /// -----------------------------------------------------------------------
    /// Validation
    /// -----------------------------------------------------------------------

    if (reward == 0) {
      return;
    }
    if (!isRewardDistributor[msg.sender]) {
      revert Error_NotRewardDistributor();
    }

    /// -----------------------------------------------------------------------
    /// Storage loads
    /// -----------------------------------------------------------------------

    uint256 rewardRate_ = rewardRate;
    uint64 periodFinish_ = periodFinish;
    uint64 lastTimeRewardApplicable_ = block.timestamp < periodFinish_
      ? uint64(block.timestamp)
      : periodFinish_;
    uint64 DURATION_ = duration;
    uint256 totalSupply_ = totalSupply;

    /// -----------------------------------------------------------------------
    /// State updates
    /// -----------------------------------------------------------------------

    // accrue rewards
    rewardPerTokenStored = _rewardPerToken(
      totalSupply_,
      lastTimeRewardApplicable_,
      rewardRate_
    );
    lastUpdateTime = lastTimeRewardApplicable_;

    // record new reward
    uint256 newRewardRate;
    if (block.timestamp >= periodFinish_) {
      newRewardRate = reward / DURATION_;
    } else {
      uint256 remaining = periodFinish_ - block.timestamp;
      uint256 leftover = remaining * rewardRate_;
      newRewardRate = (reward + leftover) / DURATION_;
    }
    // prevent overflow when computing rewardPerToken
    if (newRewardRate >= ((type(uint256).max / PRECISION) / DURATION_)) {
      revert Error_AmountTooLarge();
    }
    rewardRate = newRewardRate;
    lastUpdateTime = uint64(block.timestamp);
    periodFinish = uint64(block.timestamp + DURATION_);

    emit RewardAdded(reward);
  }

  /// @notice Lets the owner add/remove accounts from the list of reward distributors.
  /// Reward distributors can call notifyRewardAmount()
  /// @param rewardDistributor The account to add/remove
  /// @param isRewardDistributor_ True to add the account, false to remove the account
  function setRewardDistributor(
    address rewardDistributor,
    bool isRewardDistributor_
  ) external onlyOwner {
    isRewardDistributor[rewardDistributor] = isRewardDistributor_;
  }

  /// -----------------------------------------------------------------------
  /// Internal functions
  /// -----------------------------------------------------------------------

  function _earned(
    address account,
    uint256 accountBalance,
    uint256 rewardPerToken_,
    uint256 accountRewards
  ) internal view returns (uint256) {
    return
      FullMath.mulDiv(
        accountBalance,
        rewardPerToken_ - userRewardPerTokenPaid[account],
        PRECISION
      ) + accountRewards;
  }

  function _rewardPerToken(
    uint256 totalSupply_,
    uint256 lastTimeRewardApplicable_,
    uint256 rewardRate_
  ) internal view returns (uint256) {
    if (totalSupply_ == 0) {
      return rewardPerTokenStored;
    }
    return
      rewardPerTokenStored +
      FullMath.mulDiv(
        (lastTimeRewardApplicable_ - lastUpdateTime) * PRECISION,
        rewardRate_,
        totalSupply_
      );
  }

  function _getImmutableVariablesOffset()
    internal
    pure
    returns (uint256 offset)
  {
    assembly {
      offset := sub(
        calldatasize(),
        add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
      )
    }
  }
}