// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

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
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

abstract contract BaseL2MetaCube is Ownable {

    address public l2MetaCube;

    constructor(address l2MetaCube_) {
        l2MetaCube = l2MetaCube_;
    }

    function setL2MetaCube(address l2MetaCube_) external onlyOwner {
        l2MetaCube = l2MetaCube_;
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

abstract contract BaseL2MetaCubeRule is Ownable {

    address public l2MetaCubeRule;

    constructor(address l2MetaCubeRule_) {
        l2MetaCubeRule = l2MetaCubeRule_;
    }

    function setL2MetaCubeRule(address l2MetaCubeRule_) external onlyOwner {
        l2MetaCubeRule = l2MetaCubeRule_;
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

abstract contract BaseL2Unicorn is Ownable {

    address public l2Unicorn;

    constructor(address l2Unicorn_) {
        l2Unicorn = l2Unicorn_;
    }

    function setL2Unicorn(address l2Unicorn_) external onlyOwner {
        l2Unicorn = l2Unicorn_;
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

abstract contract BaseL2UnicornRule is Ownable {

    address public l2UnicornRule;

    constructor(address l2UnicornRule_) {
        l2UnicornRule = l2UnicornRule_;
    }

    function setL2UnicornRule(address l2UnicornRule_) external onlyOwner {
        l2UnicornRule = l2UnicornRule_;
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IRewardsManager} from "../interfaces/IRewardsManager.sol";

abstract contract RewardsManager is IRewardsManager, Ownable {

    address public rewardsToken;

    uint256 public rewardsAmount;

    constructor(address rewardsToken_, uint256 rewardsAmount_) {
        rewardsToken = rewardsToken_;
        rewardsAmount = rewardsAmount_;
    }

    function setRewardsToken(address rewardsToken_) external onlyOwner {
        rewardsToken = rewardsToken_;
    }

    function setRewardsAmount(uint256 rewardsAmount_) external onlyOwner {
        rewardsAmount = rewardsAmount_;
    }

    function withdrawRewards(address recipient_, uint256 amount_) external onlyOwner {
        IERC20(rewardsToken).transfer(recipient_, amount_);
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {IL2Unicorn} from "../interfaces/IL2Unicorn.sol";
import {IL2UnicornRule} from "../interfaces/IL2UnicornRule.sol";
import {IL2MetaCube} from "../interfaces/IL2MetaCube.sol";
import {IL2MetaCubeRule} from "../interfaces/IL2MetaCubeRule.sol";

import {BaseL2Unicorn} from "../abstract/BaseL2Unicorn.sol";
import {BaseL2UnicornRule} from "../abstract/BaseL2UnicornRule.sol";
import {BaseL2MetaCube} from "../abstract/BaseL2MetaCube.sol";
import {BaseL2MetaCubeRule} from "../abstract/BaseL2MetaCubeRule.sol";
import {RewardsManager} from "../abstract/RewardsManager.sol";

contract L2NonFungibleTokenResolver is BaseL2Unicorn, BaseL2UnicornRule, BaseL2MetaCube, BaseL2MetaCubeRule, RewardsManager {

    event Resolve (
        address indexed user,
        address collection,
        uint8 level,
        uint256 tokenId,
        uint256 awardAmount
    );

    constructor(address l2Unicorn_, address l2UnicornRule_, address l2MetaCube_, address l2MetaCubeRule_, address rewardsToken_)
        BaseL2Unicorn(l2Unicorn_)
        BaseL2UnicornRule(l2UnicornRule_)
        BaseL2MetaCube(l2MetaCube_)
        BaseL2MetaCubeRule(l2MetaCubeRule_)
        RewardsManager(rewardsToken_, 0) {}

    function resolveL2Unicorn(uint256[] calldata tokenIdArr) external {
        uint256 length = tokenIdArr.length;
        uint256 totalAwardAmount;
        for (uint256 i_ = 0; i_ < length;) {
            uint256 tokenId_ = tokenIdArr[i_];
            require(_msgSender() == IERC721(l2Unicorn).ownerOf(tokenId_), "L2NonFungibleTokenResolver: incorrect owner");
            IL2UnicornRule.HatchRule memory hatchRule = IL2UnicornRule(l2UnicornRule).getHatchRuleByTokenId(tokenId_);
            uint256 awardAmount_ = hatchRule.awardAmount;
            require(awardAmount_ > 0, "L2NonFungibleTokenResolver: award amount is zero");
            totalAwardAmount += awardAmount_;
            emit Resolve(_msgSender(), l2Unicorn, hatchRule.level, tokenId_, awardAmount_);
            unchecked{++i_;}
        }
        IL2Unicorn(l2Unicorn).batchBurn(tokenIdArr);
        if (totalAwardAmount > 0) {
            IERC20(rewardsToken).transfer(_msgSender(), totalAwardAmount * 1e18);
        }
    }

    function resolveL2MetaCube(uint256[] calldata tokenIdArr) external {
        uint256 length = tokenIdArr.length;
        uint256 totalAwardAmount;
        for (uint256 i_ = 0; i_ < length;) {
            uint256 tokenId_ = tokenIdArr[i_];
            require(_msgSender() == IERC721(l2MetaCube).ownerOf(tokenId_), "L2NonFungibleTokenResolver: incorrect owner");
            IL2MetaCubeRule.TokenIdRule memory tokenIdRule = IL2MetaCubeRule(l2MetaCubeRule).getTokenIdRuleByTokenId(tokenId_);
            uint256 awardAmount_ = tokenIdRule.awardAmount;
            require(awardAmount_ > 0, "L2NonFungibleTokenResolver: award amount is zero");
            totalAwardAmount += awardAmount_;
            emit Resolve(_msgSender(), l2MetaCube, tokenIdRule.level, tokenId_, awardAmount_);
            unchecked{++i_;}
        }
        IL2MetaCube(l2MetaCube).batchBurn(tokenIdArr);
        if (totalAwardAmount > 0) {
            IERC20(rewardsToken).transfer(_msgSender(), totalAwardAmount * 1e18);
        }
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IL2MetaCube {

    function mintForLevel(address to_, uint8 level_, uint256 levelStartTokenId_) external returns (uint256);

    function batchBurn(uint256[] calldata tokenIdArr) external;

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IL2MetaCubeRule {

    struct TokenIdRule {
        uint8 level;
        uint256 startTokenId;
        uint256 endTokenId;
        uint256 tokenIdTotalSupply;
        uint256 awardAmount;
    }

    struct MergeRule {
        uint8 level;
        uint256 startRandomNum;
        uint256 endRandomNum;
    }

    function modNumber() external view returns (uint256);

    function getTokenIdRuleByLevel(uint8 level_) external pure returns (TokenIdRule memory);

    function getTokenIdRuleByTokenId(uint256 tokenId_) external pure returns (TokenIdRule memory);

    function getTokenIdRuleByUnicornLevelRandomNum(uint8 unicornLevel_, uint256 randomNum_) external pure returns (TokenIdRule memory);

    function getMergeRuleByUnicornLevelLevel(uint8 unicornLevel_, uint8 level_) external pure returns (MergeRule memory);

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IL2Unicorn {

    function mintForLevel(address to_, uint8 level_, uint256 levelStartTokenId_) external returns (uint256);

    function batchBurn(uint256[] calldata tokenIdArr) external;

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IL2UnicornRule {

    struct HatchRule {
        uint8 level;
        uint256 startRandomNumE0;
        uint256 endRandomNumE0;
        uint256 startRandomNumE1;
        uint256 endRandomNumE1;
        uint256 startRandomNumE2;
        uint256 endRandomNumE2;
        uint256 startTokenId;
        uint256 endTokenId;
        uint256 tokenIdTotalSupply;
        uint256 awardAmount;
    }

    struct EvolveRule {
        uint8 level;
        uint256 startRandomNum;
        uint256 endRandomNum;
    }

    function modNumber() external view returns (uint256);

    function getHatchRuleNone() external pure returns (HatchRule memory);

    function getHatchRuleByLevel(uint8 level_) external pure returns (HatchRule memory);

    function getHatchRuleByESeriesRandomNum(uint8 eSeries_, uint256 randomNum_) external pure returns (HatchRule memory);

    function getHatchRuleByTokenId(uint256 tokenId) external pure returns (HatchRule memory);

    function getHatchRuleByEvolveTokenIdLevelRandomNum(uint8 evolveTokenIdLevel_, uint256 randomNum_) external pure returns (HatchRule memory);

    function getEvolveRuleByEvolveTokenIdLevelNextLevelIndex(uint8 evolveTokenIdLevel_, uint8 nextLevelIndex_) external pure returns (EvolveRule memory);

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IRewardsManager {

    function rewardsToken() external returns (address);

    function setRewardsToken(address rewardsToken_) external;

    function rewardsAmount() external returns (uint256);

    function setRewardsAmount(uint256 rewardsAmount_) external;

    function withdrawRewards(address recipient_, uint256 amount_) external;

}