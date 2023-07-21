// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "solmate/src/utils/MerkleProofLib.sol";

error InvalidToken();
error InvalidMerkleProof();
error AllocatedTokensAlreadyClaimed();
error ProjectDoesNotExist();
error CallerNotProjectOwner();
error ReceiverAlreadyClaimedTokens();
error TokenTransferFailed();
error ProjectAlreadyExist();
error ProjectStartClaimed();

struct Project {
    address token;
    bytes32 root;
    string projectName;
    address projectOwner;
    uint256 allocated;
    uint256 claimed;
}

// ______________________________  _______________    .___                                    ____   ____________
// \_   _____/\______   \_   ___ \ \_____  \   _  \   |   | ______ ________ __   ___________  \   \ /   /\_____  \
//  |    __)_  |       _/    \  \/  /  ____/  /_\  \  |   |/  ___//  ___/  |  \_/ __ \_  __ \  \   Y   /  /  ____/
//  |        \ |    |   \     \____/       \  \_/   \ |   |\___ \ \___ \|  |  /\  ___/|  | \/   \     /  /       \
// /_______  / |____|_  /\______  /\_______ \_____  / |___/____  >____  >____/  \___  >__|       \___/   \_______ \
//         \/         \/        \/         \/     \/           \/     \/            \/                           \/

contract ERC20IssuerV2 is Ownable {
    mapping(IERC20 token => bool supported) public _tokens;
    mapping(string id => Project project) public _projects;
    mapping(address tokenReceiver => mapping(string projectId => bool claimed))
        public _hasClaimed;

    event ProjectSet(
        string id,
        address token,
        bytes32 root,
        string projectName,
        address projectOwner,
        uint256 allocated
    );
    event ProjectUpdate(
        string id,
        address token,
        bytes32 root,
        string projectName,
        address projectOwner,
        uint256 allocated
    );

    /// @notice Constructor sets the tokenHolder address and supported tokens.
    /// @param tokens supported tokens.
    constructor(IERC20[] memory tokens) {
        for (uint256 i = 0; i < tokens.length; i++) {
            _tokens[tokens[i]] = true;
        }
    }

    /// @notice Issues tokens to a receiver.
    /// @param id The id of the merkle root.
    /// @param amount The amount of the token to be issued.
    /// @param proof The merkle proof.
    function issueTokens(
        string calldata id,
        uint256 amount,
        bytes32[] calldata proof
    ) external {
        address receiver = msg.sender;
        address token = _projects[id].token;
        uint256 allocated = _projects[id].allocated;
        uint256 claimed = _projects[id].claimed;

        if (token == address(0)) revert ProjectDoesNotExist();
        if (_hasClaimed[msg.sender][id]) revert ReceiverAlreadyClaimedTokens();
        if (allocated <= claimed) revert AllocatedTokensAlreadyClaimed();
        if (!_verify(id, _leaf(receiver, address(token), amount), proof)) {
            revert InvalidMerkleProof();
        }

        _hasClaimed[receiver][id] = true;
        _projects[id].claimed += amount;
        IERC20(token).approve(address(this), amount);
        IERC20(token).transferFrom(address(this), receiver, amount);
    }

    /// @notice Allows the project owner to reclaim unclaimed tokens.
    /// @dev Reverts if the project does not exist, the caller is not the project owner or the allocated tokens have been claimed.
    /// @param id The id of the project.
    function reclaimTokens(string calldata id) external {
        uint256 allocated = _projects[id].allocated;
        uint256 claimed = _projects[id].claimed;

        if (address(_projects[id].token) == address(0))
            revert ProjectDoesNotExist();
        if (msg.sender != _projects[id].projectOwner)
            revert CallerNotProjectOwner();
        if (allocated <= claimed) revert AllocatedTokensAlreadyClaimed();

        uint256 reclaimAmount = allocated - claimed;
        _projects[id].claimed = allocated;

        IERC20(_projects[id].token).approve(address(this), reclaimAmount);
        IERC20(_projects[id].token).transferFrom(
            address(this),
            _projects[id].projectOwner,
            reclaimAmount
        );
    }

    /// @notice Sets a new project with a specific token, merkle root, project name, project owner and total allocated tokens.
    /// @dev Only callable by the owner of this contract.
    /// @param token The token to be issued.
    /// @param id The id for this project.
    /// @param root The root of the merkle tree.
    /// @param projectName The name of the project.
    /// @param allocated The total allocated tokens for the project.
    function setProject(
        address token,
        string calldata id,
        bytes32 root,
        string memory projectName,
        uint256 allocated
    ) external {
        address projectOwner = msg.sender;
        if (!_tokens[IERC20(token)]) revert InvalidToken();
        if (_projects[id].projectOwner != address(0)) revert ProjectAlreadyExist();
        _projects[id] = Project(
            token,
            root,
            projectName,
            projectOwner,
            allocated,
            0
        );

        IERC20(token).transferFrom(projectOwner, address(this), allocated);

        emit ProjectSet(
            id,
            address(token),
            root,
            projectName,
            projectOwner,
            allocated
        );
    }

    /// @notice Update existed project with a specific token, merkle root, project name, project owner and total allocated tokens.
    /// @dev Only callable by the project owner.
    /// @param token The token to be issued.
    /// @param id The id for this project.
    /// @param root The root of the merkle tree.
    /// @param projectName The name of the project.
    /// @param allocated The total allocated tokens for the project.
    function updateProject(
        address token,
        string calldata id,
        bytes32 root,
        string memory projectName,
        uint256 allocated
    ) external {
        address projectOwner = msg.sender;
        if (!_tokens[IERC20(token)]) revert InvalidToken();
        if (_projects[id].projectOwner != projectOwner) revert CallerNotProjectOwner();
     
        uint256 oldAllocated = _projects[id].allocated;
        address oldTokenAddress= _projects[id].token;
        uint256 claimed = _projects[id].claimed;
        if (claimed > 0) revert ProjectStartClaimed();

        IERC20(oldTokenAddress).transfer(projectOwner, oldAllocated);

        _projects[id] = Project(
            token,
            root,
            projectName,
            projectOwner,
            allocated,
            0
        );

        IERC20(token).transferFrom(projectOwner, address(this), allocated);
        emit ProjectUpdate(
            id,
            address(token),
            root,
            projectName,
            projectOwner,
            allocated
        );
    }

    /// @notice User increase reward token for a existing project  
    /// @param id The project id.
    /// @param amount The total deposit tokens for the project.
    function deposit(string calldata id, uint256 amount) external {
        address projectOwner = msg.sender;
        if (projectOwner != _projects[id].projectOwner)
            revert CallerNotProjectOwner();

        address token = _projects[id].token;
        _projects[id].allocated += amount;
        IERC20(token).transferFrom(projectOwner, address(this), amount);
    } 

    /// @notice Sets a token.
    /// @param token The token to be supported.
    function addToken(IERC20 token) external onlyOwner {
        _tokens[token] = true;
    }

    /// @notice Removes a token.
    /// @param token The token to be removed.
    function removeToken(IERC20 token) external onlyOwner {
        _tokens[token] = false;
    }

    /// @notice Returns a leaf of the merkle-tree.
    /// @param receiver The receiver of the tokens.
    /// @param token The token to be issued.
    /// @param amount The amount of the token to be issued.
    function _leaf(
        address receiver,
        address token,
        uint256 amount
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(receiver, token, amount));
    }

    /// @notice Verifies a given leaf is in the merkle-tree with the given root.
    function _verify(
        string calldata id,
        bytes32 leaf,
        bytes32[] calldata proof
    ) internal view returns (bool) {
        bytes32 root = _projects[id].root;
        return MerkleProofLib.verify(proof, root, leaf);
    }
}

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
pragma solidity >=0.8.0;

/// @notice Gas optimized merkle proof verification library.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/MerkleProofLib.sol)
library MerkleProofLib {
    function verify(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool isValid) {
        assembly {
            if proof.length {
                // Left shifting by 5 is like multiplying by 32.
                let end := add(proof.offset, shl(5, proof.length))

                // Initialize offset to the offset of the proof in calldata.
                let offset := proof.offset

                // Iterate over proof elements to compute root hash.
                // prettier-ignore
                for {} 1 {} {
                    // Slot where the leaf should be put in scratch space. If
                    // leaf > calldataload(offset): slot 32, otherwise: slot 0.
                    let leafSlot := shl(5, gt(leaf, calldataload(offset)))

                    // Store elements to hash contiguously in scratch space.
                    // The xor puts calldataload(offset) in whichever slot leaf
                    // is not occupying, so 0 if leafSlot is 32, and 32 otherwise.
                    mstore(leafSlot, leaf)
                    mstore(xor(leafSlot, 32), calldataload(offset))

                    // Reuse leaf to store the hash to reduce stack operations.
                    leaf := keccak256(0, 64) // Hash both slots of scratch space.

                    offset := add(offset, 32) // Shift 1 word per cycle.

                    // prettier-ignore
                    if iszero(lt(offset, end)) { break }
                }
            }

            isValid := eq(leaf, root) // The proof is valid if the roots match.
        }
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