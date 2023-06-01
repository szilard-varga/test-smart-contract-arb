// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

abstract contract MPCManageable {
  event MPCUpdated(address indexed oldMPC, address indexed newMPC, uint256 effectiveTime);

  uint256 public constant DELAY = 2 days;

  address internal _oldMPC;
  address internal _newMPC;
  uint256 internal _newMPCEffectiveTime;

  constructor(address _MPC) {
    _updateMPC(_MPC, 0);
  }

  modifier onlyMPC() {
    _checkMPC();
    _;
  }

  function mpc() public view returns (address) {
    if (block.timestamp >= _newMPCEffectiveTime) {
      return _newMPC;
    }

    return _oldMPC;
  }

  function updateMPC(address newMPC) public onlyMPC {
    _updateMPC(newMPC, DELAY);
  }

  function _updateMPC(address newMPC, uint256 delay) private {
    require(newMPC != address(0), "MPCManageable: Nullable MPC");

    _oldMPC = mpc();
    _newMPC = newMPC;
    _newMPCEffectiveTime = block.timestamp + delay;

    emit MPCUpdated(_oldMPC, _newMPC, _newMPCEffectiveTime);
  }

  function _checkMPC() internal view {
    require(msg.sender == mpc(), "MPCManageable: Non MPC");
  }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import "./interfaces/IDual.sol";
import "./libraries/math.sol";

import "./access/MPCManageable.sol";

contract DualFactory is MPCManageable, IDualFactory {
  uint256 constant DECIMALS = 18;

  mapping(bytes32 => bool) public duals;

  constructor(address _MPC) MPCManageable(_MPC) {}

  function create(Tariff memory tariff, Input memory input) public onlyMPC {
    _create(tariff, _dual(tariff, input));
  }

  function claim(Dual memory dual, uint256 closedPrice) public onlyMPC {
    _claim(dual, closedPrice);
  }

  function replay(Dual memory dual, uint256 closedPrice, Tariff calldata tariff) public onlyMPC {
    _replay(dual, closedPrice, tariff);
  }

  function _create(Tariff memory tariff, Dual memory dual) internal {
    _validate(tariff, dual);

    bytes32 id = _id(dual);

    duals[id] = true;

    emit DualCreated(
      id,
      dual.user,
      dual.chainId,
      dual.baseToken,
      dual.quoteToken,
      dual.inputToken,
      dual.inputAmount,
      dual.yield,
      dual.initialPrice,
      dual.parentHash,
      dual.finishAt
    );
  }

  function _claim(Dual memory dual, uint256 closedPrice) internal {
    bytes32 id = _id(dual);

    require(duals[id], "Dual: Not found");
    require(closedPrice > 0, "Dual: Bad closed price");
    require(block.timestamp >= dual.finishAt, "Dual: Not finished yet");

    dual.closedPrice = closedPrice;
    _output(dual);

    duals[id] = false;

    emit DualClaimed(
      id,
      dual.user,
      dual.chainId,
      dual.outputToken,
      dual.outputAmount,
      dual.closedPrice,
      dual.parentHash,
      dual.finishAt
    );
  }

  function _replay(Dual memory dual, uint256 closedPrice, Tariff calldata tariff) internal {
    _claim(dual, closedPrice);

    Input memory input = Input(
      dual.user,
      dual.outputToken,
      dual.outputAmount,
      closedPrice,
      _id(dual),
      dual.finishAt
    );

    Dual memory newDual = _dual(tariff, input);

    _create(tariff, newDual);
  }

  function _validate(Tariff memory tariff, Dual memory dual) internal view {
    require(dual.user != address(0), "Dual: Bad user");
    require(tariff.chainId != 0, "Dual: Bad chainId");
    require(
      dual.inputToken == tariff.baseToken || dual.inputToken == tariff.quoteToken,
      "Dual: Input must be one from pair"
    );
    require(dual.inputAmount > 0, "Dual: Bad amount");
    require(tariff.yield > 0, "Dual: Bad tariff yield");
    require(dual.initialPrice > 0, "Dual: Bad initialPrice");
    require(tariff.stakingPeriod > 0, "Dual: Bad tariff stakingPeriod");
    require(dual.parentHash != 0x0, "Dual: Bad parentHash");
    require(dual.finishAt > block.timestamp, "Dual: Bad finish date");
  }

  function _dual(Tariff memory tariff, Input memory input) internal pure returns (Dual memory dual) {
    dual.user = input.user;
    dual.chainId = tariff.chainId;
    dual.baseToken = tariff.baseToken;
    dual.quoteToken = tariff.quoteToken;
    dual.inputToken = input.token;
    dual.inputAmount = input.amount;
    dual.yield = tariff.yield;
    dual.initialPrice = input.initialPrice;
    dual.parentHash = input.parentHash;
    dual.finishAt = input.startedAt + tariff.stakingPeriod * 1 hours;
  }

  function _id(Dual memory dual) internal pure returns (bytes32 hash) {
    hash = keccak256(
      abi.encode(
        dual.user,
        dual.chainId,
        dual.baseToken,
        dual.quoteToken,
        dual.inputToken,
        dual.inputAmount,
        dual.yield,
        dual.initialPrice,
        dual.parentHash,
        dual.finishAt
      )
    );
  }

  function _output(Dual memory dual) internal pure {
    if (dual.closedPrice >= dual.initialPrice) {
      dual.outputToken = dual.quoteToken;

      if (dual.inputToken == dual.quoteToken) {
        dual.outputAmount = dual.inputAmount + RMath.percent(dual.inputAmount, dual.yield);
      } else {
        dual.outputAmount = (dual.inputAmount * dual.initialPrice) / 10 ** DECIMALS;
        dual.outputAmount = dual.outputAmount + RMath.percent(dual.outputAmount, dual.yield);
      }
    } else {
      dual.outputToken = dual.baseToken;

      if (dual.inputToken == dual.baseToken) {
        dual.outputAmount = dual.inputAmount + RMath.percent(dual.inputAmount, dual.yield);
      } else {
        dual.outputAmount = (dual.inputAmount * (10 ** DECIMALS)) / dual.initialPrice;
        dual.outputAmount = dual.outputAmount + RMath.percent(dual.outputAmount, dual.yield);
      }
    }
  }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

struct Dual {
  address user;
  uint256 chainId;
  address baseToken;
  address quoteToken;
  address inputToken;
  uint256 inputAmount;
  address outputToken;
  uint256 outputAmount;
  uint256 yield;
  uint256 initialPrice;
  uint256 closedPrice;
  bytes32 parentHash;
  uint256 finishAt;
}

struct Tariff {
  uint256 chainId;
  address baseToken;
  address quoteToken;
  uint256 stakingPeriod;
  uint256 yield;
}

interface IDualFactory {
  event DualCreated(
    bytes32 indexed id,
    address indexed user,
    uint256 indexed chainId,
    address baseToken,
    address quoteToken,
    address inputToken,
    uint256 inputAmount,
    uint256 yield,
    uint256 initialPrice,
    bytes32 parentHash,
    uint256 finishAt
  );

  event DualClaimed(
    bytes32 indexed id,
    address indexed user,
    uint256 indexed chainId,
    address outputToken,
    uint256 outputAmount,
    uint256 closedPrice,
    bytes32 parentHash,
    uint256 finishAt
  );

  struct Input {
    address user;
    address token;
    uint256 amount;
    uint256 initialPrice;
    bytes32 parentHash;
    uint256 startedAt;
  }

  function duals(bytes32) external view returns (bool);

  function create(Tariff memory tariff, Input memory input) external;

  function claim(Dual memory dual, uint256 closedPrice) external;

  function replay(Dual memory dual, uint256 closedPrice, Tariff memory tariff) external;
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

library RMath {
  uint32 constant PERCENT_DECIMALS = 10 ** 8;

  function percent(uint256 amount, uint256 _percent) internal pure returns (uint256) {
    return (amount * _percent) / PERCENT_DECIMALS;
  }
}