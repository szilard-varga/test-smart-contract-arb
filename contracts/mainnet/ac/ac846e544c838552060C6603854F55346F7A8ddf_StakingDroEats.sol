/**
 *Submitted for verification at Arbiscan on 2022-07-17
*/

// File: @openzeppelin/contracts/utils/introspection/IERC165.sol


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

// File: @openzeppelin/contracts/token/ERC721/IERC721.sol


// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;


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
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
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
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
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

// File: @openzeppelin/contracts/utils/Context.sol


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

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;


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

// File: @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol


// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// File: contracts/StakingDroEats.sol


pragma solidity ^0.8.4;



 
contract StakingDroEats is Ownable, IERC721Receiver {
 
    IERC721 public nft;
 
    uint16 public totalStaked;
    uint256 public stakingStartTime;
    bool public isStakingActive = false;
 
    struct Stake {
        uint16 tokenId;
        uint256 timestamp;
        uint256 totalTimeStaked;
        address owner;
        bool active;
    }
 
    mapping (address => uint16[]) Stakes;
    mapping (uint256 => Stake) public Vault;
 
    modifier ownerOfToken(uint256 tokenId) {
        require(msg.sender == nft.ownerOf(tokenId), "You are not owner of the token");
        _;
    }
 
    modifier ownerOfStake(uint256 tokenId) {
        require(msg.sender == Vault[tokenId].owner, "You are not an owner of this stake");
        _;
    }
 
    modifier isNotStakedYet(uint256 tokenId) {
        require(Vault[tokenId].active == false, "This Stake does not belong to you");
        _;
    }
 
    modifier stakingActive() {
        require(isStakingActive, "Staking is not active yet");
        _;
    }
 
    event Staked(address by, uint16 tokenId);
    event Unstaked(address by, uint16 tokenId);
 
    constructor(address _nft) {
        nft = IERC721(_nft);
    }
 
    function pushToStakedTracker(address add, uint16 tokenId) 
    internal 
    {
        Stakes[add].push(tokenId);
    }
 
    function popFromStakedTracker(address add, uint16 tokenId) 
    internal 
    {
        for(uint i=0;i<Stakes[add].length;i++)
        {
            if(Stakes[add][i] == tokenId)
            {
                Stakes[add][i] = 9999;
            }
        }
    }
 
    function stake(uint256 tokenId) 
    public 
    ownerOfToken(tokenId) isNotStakedYet(tokenId) stakingActive
    {
        totalStaked++;
        if(Vault[tokenId].owner == address(0))
        {
            Vault[tokenId] = Stake({
                tokenId: uint16(tokenId),
                timestamp: block.timestamp,
                totalTimeStaked: 0,
                owner: msg.sender,
                active: true
            });
            pushToStakedTracker(msg.sender, uint16(tokenId));
        }
        else if(Vault[tokenId].owner != msg.sender)
        {
            Vault[tokenId].owner = msg.sender;
            Vault[tokenId].active = true;
            Vault[tokenId].timestamp = block.timestamp;
            pushToStakedTracker(msg.sender, uint16(tokenId));
        }
        else
        {
            Vault[tokenId].active = true;
            Vault[tokenId].timestamp = block.timestamp;
            pushToStakedTracker(msg.sender, uint16(tokenId));
        }
        nft.safeTransferFrom(msg.sender, address(this), tokenId, "0x00");
        emit Staked(msg.sender, uint16(tokenId));
    }
 
    function unstake(uint256 tokenId) 
    public
    ownerOfStake(tokenId) stakingActive
    {
        totalStaked--;
        Vault[tokenId].active = false;
        Vault[tokenId].totalTimeStaked += block.timestamp - Vault[tokenId].timestamp;
        Vault[tokenId].timestamp = 0;
        popFromStakedTracker(msg.sender, uint16(tokenId));
        nft.safeTransferFrom(address(this), msg.sender, tokenId);
        emit Unstaked(msg.sender, uint16(tokenId));
    }
 
    function stakeMany(uint256[] calldata tokenIds) 
    external
    stakingActive
    {
        for(uint i=0; i<tokenIds.length; i++)
        {
            stake(tokenIds[i]);
        }
    }
 
    function unstakeMany(uint256[] calldata tokenIds) 
    external
    stakingActive
    {
        for(uint i=0; i<tokenIds.length; i++)
        {
            unstake(tokenIds[i]);
        }
    }
 
    function stakedTimeInfo(uint256 tokenId)
    external view returns(uint256) 
    {
        return (Vault[tokenId].totalTimeStaked + (block.timestamp - Vault[tokenId].timestamp));
    }
 
    function onERC721Received(address, address from, uint256, bytes calldata) 
    external pure override returns (bytes4) {
      return IERC721Receiver.onERC721Received.selector;
    }
 
    function toggleStaking(bool state)
    external onlyOwner
    {
        isStakingActive = state;
        stakingStartTime = block.timestamp;
    }
 
    function setNewErc721Contract(address _nft)
    external onlyOwner
    {
        nft=IERC721(_nft);
    }
 
    function getStakedTokens(address owner) 
    external view returns(uint16[] memory) 
    {
        return Stakes[owner];
    } 
}