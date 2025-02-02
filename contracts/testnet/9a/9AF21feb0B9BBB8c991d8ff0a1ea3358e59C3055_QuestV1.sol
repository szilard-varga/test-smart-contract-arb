// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../Realm/IRealm.sol";
import "../Utils/IRand.sol";
import "../Adventurer/IAdventurerData.sol";
import "./IQuest.sol";

import "../Manager/ManagerModifier.sol";

contract QuestV1 is IQuest, ManagerModifier, ReentrancyGuard {
  //=======================================
  // Immutables
  //=======================================
  IRealm public immutable REALM;
  IAdventurerData public immutable ADVENTURER_DATA;
  IRand public randomizer;

  //=======================================
  // Struct
  //=======================================
  struct Quest {
    uint32 xp;
    uint32 traitId;
    uint32 traitAmount;
    uint8[6] geos;
  }

  //=======================================
  // Arrays
  //==================,=====================
  uint256[] public bonusProbability = [50, 75, 85, 95, 100];

  //=======================================
  // Uints
  //=======================================
  uint256 public animaBaseReward;
  uint256 public professionBonus;

  //=======================================
  // Mappings
  //=======================================
  mapping(uint256 => Quest) public quests;

  //=======================================
  // Constructor
  //=======================================
  constructor(
    address _realm,
    address _manager,
    address _advData,
    address _rand,
    uint256 _animaBaseReward,
    uint256 _professionBonus
  ) ManagerModifier(_manager) {
    REALM = IRealm(_realm);
    ADVENTURER_DATA = IAdventurerData(_advData);
    randomizer = IRand(_rand);

    quests[0] = Quest({
      xp: 1,
      traitId: 4,
      traitAmount: 5,
      geos: [1, 7, 5, 0, 11, 25]
    });
    quests[1] = Quest({
      xp: 1,
      traitId: 3,
      traitAmount: 5,
      geos: [12, 23, 33, 14, 28, 26]
    });
    quests[2] = Quest({
      xp: 1,
      traitId: 2,
      traitAmount: 5,
      geos: [8, 4, 27, 34, 3, 21]
    });
    quests[3] = Quest({
      xp: 1,
      traitId: 7,
      traitAmount: 5,
      geos: [2, 17, 6, 10, 13, 15]
    });
    quests[4] = Quest({
      xp: 1,
      traitId: 6,
      traitAmount: 5,
      geos: [31, 32, 24, 19, 29, 9]
    });
    quests[5] = Quest({
      xp: 1,
      traitId: 5,
      traitAmount: 5,
      geos: [16, 22, 18, 20, 30, 32]
    });

    // Base reward for anima per quest
    animaBaseReward = _animaBaseReward;

    // Profession bonus
    professionBonus = _professionBonus;
  }

  //=======================================
  // External
  //=======================================
  function go(
    address _addr,
    uint256 _adventurerId,
    uint256 _questId,
    uint256 _realmId
  )
    external
    view
    override
    onlyManager
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    Quest memory quest = quests[_questId];

    // Check realm exists
    REALM.ownerOf(_realmId);

    // Check quest exists
    require(quest.xp > 0, "QuestV1: Quest does not exist");

    // Check realm has geo feature
    require(
      _hasGeo(_realmId, quest),
      "QuestV1: Realm does not have Geo Feature needed"
    );

    return (
      quest.xp,
      quest.traitId,
      _traitAmount(quest.traitAmount, _adventurerId),
      _anima(_addr, _adventurerId)
    );
  }

  //=======================================
  // Admin
  //=======================================
  function updateQuests(
    uint256 _questId,
    uint32 _xp,
    uint32 _traitId,
    uint32 __traitAmount,
    uint8[6] memory _geos
  ) external onlyAdmin {
    Quest storage quest = quests[_questId];

    quest.xp = _xp;
    quest.traitId = _traitId;
    quest.traitAmount = __traitAmount;
    quest.geos = _geos;
  }

  function updateAnimaBaseRewards(uint256 _animaBaseReward) external onlyAdmin {
    animaBaseReward = _animaBaseReward;
  }

  function updateProfessionBonus(uint256 _professionBonus) external onlyAdmin {
    professionBonus = _professionBonus;
  }

  //=======================================
  // Internal
  //=======================================
  function _traitAmount(uint256 _base, uint256 _adventurerId)
    internal
    view
    returns (uint256)
  {
    // Add trait bonus to base
    return _base + _traitBonus(_adventurerId);
  }

  function _anima(address _addr, uint256 _adventurerId)
    internal
    view
    returns (uint256)
  {
    // Retrieve adventurer data
    uint256[] memory properties = _adventurerData(_addr, _adventurerId);

    // Calculate anima based on transcendence level
    uint256 anima = properties[0] * animaBaseReward;

    // Check if profession is Zealot
    if (properties[3] == 3) {
      anima += professionBonus;
    }

    return anima;
  }

  function _hasGeo(uint256 _realmId, Quest memory quest)
    internal
    view
    returns (bool)
  {
    bool valid;
    (uint256 a, uint256 b, uint256 c) = _realmFeatures(_realmId);

    for (uint256 j = 0; j < quest.geos.length; j++) {
      if (a == quest.geos[j] || b == quest.geos[j] || c == quest.geos[j]) {
        valid = true;
      }
    }

    return valid;
  }

  function _realmFeatures(uint256 _realmId)
    internal
    view
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    return (
      REALM.realmFeatures(_realmId, 0),
      REALM.realmFeatures(_realmId, 1),
      REALM.realmFeatures(_realmId, 2)
    );
  }

  function _adventurerData(address _addr, uint256 _adventurerId)
    internal
    view
    returns (uint256[] memory)
  {
    return ADVENTURER_DATA.aovProperties(_addr, _adventurerId, 0, 3);
  }

  function _traitBonus(uint256 _salt) internal view returns (uint256) {
    uint256 rand = uint256(
      keccak256(
        abi.encodePacked(
          block.number,
          block.timestamp,
          randomizer.retrieve(_salt)
        )
      )
    ) % 100;

    uint256 j = 0;

    for (; j < bonusProbability.length; j++) {
      if (rand <= bonusProbability[j]) {
        break;
      }
    }

    return j;
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IRealm {
  function balanceOf(address owner) external view returns (uint256);

  function ownerOf(uint256 _realmId) external view returns (address owner);

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) external;

  function isApprovedForAll(address owner, address operator)
    external
    returns (bool);

  function realmFeatures(uint256 realmId, uint256 index)
    external
    view
    returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IRand {
  function retrieve(uint256 _salt) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IAdventurerData {
  function initData(
    address _addr,
    uint256 _id,
    uint256 _profession,
    uint256[6] calldata _points
  ) external;

  function baseProperties(
    address _addr,
    uint256 _id,
    uint256 _start,
    uint256 _end
  ) external view returns (uint256[] memory);

  function aovProperties(
    address _addr,
    uint256 _id,
    uint256 _start,
    uint256 _end
  ) external view returns (uint256[] memory);

  function extensionProperties(
    address _addr,
    uint256 _id,
    uint256 _start,
    uint256 _end
  ) external view returns (uint256[] memory);

  function createFor(address _addr, uint256 _id) external;

  function createFor(
    address _addr,
    uint256 _id,
    uint256 _archetype
  ) external;

  function createFor(
    address _addr,
    uint256 _id,
    uint256 _archetype,
    uint256 _profession
  ) external;

  function createFor(
    address _addr,
    uint256 _id,
    uint256 _archetype,
    uint256 _profession,
    uint256[6] calldata _points
  ) external;

  function moveFor(
    address _existingAddr,
    uint256 _existingId,
    address _addr,
    uint256 _id
  ) external;

  function addToBase(
    address _addr,
    uint256 _id,
    uint256 _prop,
    uint256 _val
  ) external;

  function updateBase(
    address _addr,
    uint256 _id,
    uint256 _prop,
    uint256 _val
  ) external;

  function removeFromBase(
    address _addr,
    uint256 _id,
    uint256 _prop,
    uint256 _val
  ) external;

  function addToAov(
    address _addr,
    uint256 _id,
    uint256 _prop,
    uint256 _val
  ) external;

  function updateAov(
    address _addr,
    uint256 _id,
    uint256 _prop,
    uint256 _val
  ) external;

  function removeFromAov(
    address _addr,
    uint256 _id,
    uint256 _prop,
    uint256 _val
  ) external;

  function addToExtension(
    address _addr,
    uint256 _id,
    uint256 _prop,
    uint256 _val
  ) external;

  function updateExtension(
    address _addr,
    uint256 _id,
    uint256 _prop,
    uint256 _val
  ) external;

  function removeFromExtension(
    address _addr,
    uint256 _id,
    uint256 _prop,
    uint256 _val
  ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IQuest {
  function go(
    address _addr,
    uint256 _adventurerId,
    uint256 _questId,
    uint256 _realmId
  )
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    );
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../Manager/IManager.sol";

abstract contract ManagerModifier {
  //=======================================
  // Immutables
  //=======================================
  IManager public immutable MANAGER;

  //=======================================
  // Constructor
  //=======================================
  constructor(address _manager) {
    MANAGER = IManager(_manager);
  }

  //=======================================
  // Modifiers
  //=======================================
  modifier onlyAdmin() {
    require(MANAGER.isAdmin(msg.sender), "Manager: Not an Admin");
    _;
  }

  modifier onlyManager() {
    require(MANAGER.isManager(msg.sender, 0), "Manager: Not manager");
    _;
  }

  modifier onlyMinter() {
    require(MANAGER.isManager(msg.sender, 1), "Manager: Not minter");
    _;
  }

  modifier onlyTokenMinter() {
    require(MANAGER.isManager(msg.sender, 2), "Manager: Not token minter");
    _;
  }

  modifier onlyBinder() {
    require(MANAGER.isManager(msg.sender, 3), "Manager: Not binder");
    _;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IManager {
  function isAdmin(address _addr) external view returns (bool);

  function isManager(address _addr, uint256 _type) external view returns (bool);

  function addManager(address _addr, uint256 _type) external;

  function removeManager(address _addr, uint256 _type) external;

  function addAdmin(address _addr) external;

  function removeAdmin(address _addr) external;
}