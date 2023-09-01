// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

//   ,,==.
//  //    `
// ||      ,--~~~~-._ _(\--,_
//  \\._,-~   \      '    *  `o
//   `---~\( _/,___( /_/`---~~
//         ``==-    `==-,

import "openzeppelin/contracts/access/Ownable.sol";
import "openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin/contracts/security/ReentrancyGuard.sol";
import "chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "./interfaces/IRabbleRabble.sol";

contract RabbleRabble is Ownable, VRFConsumerBaseV2, IERC721Receiver, IRabbleRabble, ReentrancyGuard {
    bool public paused;
    address public multisig;
    address public addressZero = address(0);
    uint256 public maxTimeLimit;

    uint256 public raffleCounter;
    mapping(uint256 => Raffle) public raffles;
    mapping(uint256 => mapping(address => bool)) public raffleIdToWhitelisted;

    uint256 public fee;
    uint256 public collectableFees;

    mapping(uint256 => RequestStatus) public requests;

    VRFCoordinatorV2Interface public vrfCoordinator;

    uint64 public subscriptionId;
    uint32 public numWords = 1;
    uint32 public callbackGasLimit;
    uint16 public requestConfirmations = 3;
    bytes32 public keyHash;

    modifier isPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier EOA() {
        if (msg.sender != tx.origin) revert UnableToJoin();
        _;
    }

    /**
     * @notice Constructor
     * @param _multisig The address of the multisig wallet
     * @param _fee The fee in wei for each raffle
     * @param _maxTimeLimit The max time limit for each raffle
     * @param _vrfCoordinator The address of the VRF Coordinator
     * @param _keyHash The key hash for the VRF Coordinator
     * @param _subscriptionId The subscription id for the VRF Coordinator
     * @param _callbackGasLimit The callback gas limit for the VRF Coordinator
     */
    constructor(
        address _multisig,
        uint256 _fee,
        uint256 _maxTimeLimit,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        maxTimeLimit = _maxTimeLimit;
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        callbackGasLimit = _callbackGasLimit;
        multisig = _multisig;
        fee = _fee;
    }

    ////////////////////
    //      View      //
    ////////////////////

    /**
     * @notice IERC721Receiver implementation
     */
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @notice Retrieves entire raffle struct
     * @param raffleId The id of the raffle
     * @return Raffle struct
     */
    function getRaffle(uint256 raffleId) external view returns (Raffle memory) {
        return raffles[raffleId];
    }

    ////////////////////
    //     Public     //
    ////////////////////

    /**
     * @notice Create public raffle with no whitelist where anyone can participate
     * @param collection IERC721 address of the collection being raffled among participants
     * @param numberOfParticipants The number of participants in the raffle
     * @param tokenId The tokenId of the NFT being raffled owned by raffle creator
     * @param timeLimit The time limit for the raffle to be filled
     */
    function createPublicRaffle(IERC721 collection, uint256 numberOfParticipants, uint256 tokenId, uint256 timeLimit)
        external
        payable
    {
        if (msg.value < fee) revert WrongMessageValue();
        address[] memory emptyWhitelist = new address[](0);

        _createNewRaffle(collection, timeLimit, tokenId, numberOfParticipants, emptyWhitelist);
    }

    /**
     * @notice Create private raffle with whitelist where only whitelisted users can participate and add users to whitelist
     * @param collection IERC721 address of the collection being raffled among participants
     * @param numberOfParticipants The number of participants in the raffle
     * @param tokenId The tokenId of the NFT being raffled owned by raffle creator
     * @param whitelist The list of addresses that are whitelisted to participate in the raffle
     * @param timeLimit The time limit for the raffle to be filled
     */
    function createPrivateRaffle(
        IERC721 collection,
        uint256 numberOfParticipants,
        uint256 tokenId,
        address[] memory whitelist,
        uint256 timeLimit
    ) external payable {
        if (msg.value != fee) revert WrongMessageValue();

        _createNewRaffle(collection, timeLimit, tokenId, numberOfParticipants, whitelist);
    }

    /**
     * @notice Join a raffle by indicating raffleId and tokenId of the collection being raffled
     * If raffle is not full by the time raffle ending time is reached, refunds all users with paid fees and NFTs.
     * If raffle is full, calls Chainlink VRF to select a winner and transfers NFTs to winner.
     * @param raffleId The id of the raffle
     * @param tokenId The tokenId of the NFT being raffled
     */
    function joinRaffle(uint256 raffleId, uint256 tokenId) external payable isPaused EOA {
        Raffle storage raffle = raffles[raffleId];
        // check if raffle is active
        if (raffle.winner != addressZero) revert RaffleNotActive();
        // check if raffle is time limit is over
        if (raffle.endingTime < block.timestamp) {
            _refundRaffle(raffleId);
        } else {
            // check if fee is paid
            if (msg.value != fee) revert WrongMessageValue();

            // check if raffle is full
            if (raffle.participantsList.length >= raffle.numberOfParticipants) {
                revert RaffleFull();
            }

            // check if user is whitelisted
            if (!raffle.isPublic && !raffleIdToWhitelisted[raffleId][msg.sender]) {
                revert UnableToJoin();
            }

            if (raffle.collection.ownerOf(tokenId) != msg.sender) {
                revert NotOwnerOf();
            }

            // check if user is already in the raffle
            for (uint256 i = 0; i < raffle.participantsList.length; i++) {
                if (raffle.participantsList[i] == msg.sender) {
                    revert AlreadyInRaffle();
                }
            }

            // Transfer NFT to rabble contract
            _transferToVault(raffles[raffleId].collection, tokenId);

            // Store fees
            raffle.fees += msg.value;

            // add user to the raffle
            raffles[raffleId].participantsList.push(msg.sender);

            // Register NFT to raffle
            raffles[raffleId].tokenIds.push(tokenId);

            // check if raffle is full, if so, request random number and finalize raffle
            if (raffles[raffleId].participantsList.length >= raffles[raffleId].numberOfParticipants) {
                raffle.requested = true;
                uint256 requestId = vrfCoordinator.requestRandomWords(
                    keyHash, subscriptionId, requestConfirmations, callbackGasLimit, numWords
                );
                requests[requestId] = RequestStatus({raffleId: raffleId, randomWord: 0, fulfilled: false});
                emit RaffleRequest(raffleId, requestId);
            }

            emit RaffleJoined(raffleId, msg.sender, tokenId);
        }
    }

    /**
     * @notice Adds more users to whitelist. Anyone that has been whitelisted can whitelist users
     * @param raffleId The id of the raffle
     * @param whitelist The list of addresses to be whitelisted
     */
    function addToWhitelist(uint256 raffleId, address[] calldata whitelist) external isPaused {
        Raffle storage raffle = raffles[raffleId];
        if (raffle.winner != addressZero) revert RaffleNotActive();
        if (raffle.endingTime < block.timestamp) {
            revert EndingTimeReached();
        }
        if (raffle.isPublic) revert RaffleIsPublic();
        if (!raffleIdToWhitelisted[raffleId][msg.sender]) {
            revert UnableToWhitelist();
        }
        for (uint256 i; i < whitelist.length; i++) {
            raffleIdToWhitelisted[raffleId][whitelist[i]] = true;
        }

        emit AddedToWhitelist(raffleId, whitelist);
    }

    ////////////////////
    //     Owner      //
    ////////////////////

    /**
     * @notice Collects fees from the contract
     */
    function collectFee() external onlyOwner nonReentrant {
        uint256 collect = collectableFees;
        collectableFees = 0;
        (bool sent,) = multisig.call{value: collect}("");
        if (!sent) {
            revert UnableToCollect();
        }
    }

    /**
     * @notice Toggles paused state between true and false
     */
    function togglePause() external onlyOwner {
        paused = !paused;
    }

    /**
     * @notice Sets the fee for creating a raffle
     * @param _fee The new fee
     */
    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    /**
     * @notice Sets the max time limit users can set for a raffle
     * @param _maxTimeLimit The new max time limit
     */
    function setMaxTimeLimit(uint256 _maxTimeLimit) external onlyOwner {
        maxTimeLimit = _maxTimeLimit;
    }

    function refundRaffle(uint256 raffleId) external onlyOwner {
        _refundRaffle(raffleId);
    }

    ////////////////////
    //    Internal    //
    ////////////////////

    // full refund if the lobby isnt filled
    function _refundRaffle(uint256 raffleId) internal nonReentrant {
        Raffle storage raffle = raffles[raffleId];

        // Check if request to chainlink has been made already
        if (raffle.requested) revert AlreadyFinalized();

        // Check if raffle is active
        if (raffle.winner != addressZero) revert RaffleNotActive();

        // If user tried joing a raffle that is not full but was late, refund them
        if (msg.value > 0) {
            (bool sent,) = msg.sender.call{value: msg.value}("");
            if (!sent) {
                revert UnableToRefund();
            }
        }

        // Refund all participants
        uint256 feeToReturn = raffle.fees / raffle.participantsList.length;
        raffle.fees = 0;
        for (uint256 i; i < raffle.participantsList.length; i++) {
            raffle.collection.transferFrom(address(this), raffle.participantsList[i], raffle.tokenIds[i]);

            (bool sent,) = raffle.participantsList[i].call{value: feeToReturn}("");
            if (!sent) {
                revert UnableToRefund();
            }
        }
        emit RaffleRefunded(raffleId);
    }

    // Generic create raffle function
    function _createNewRaffle(
        IERC721 collection,
        uint256 timeLimit,
        uint256 tokenId,
        uint256 numberOfParticipants,
        address[] memory whitelist
    ) internal isPaused EOA {
        if (timeLimit > maxTimeLimit) revert InvalidTimelimit();
        if (numberOfParticipants < 2 || numberOfParticipants > 100) revert InvalidNumberOfParticipants();
        if (collection.ownerOf(tokenId) != msg.sender) revert NotOwnerOf();

        // transfer token to raffle contract
        _transferToVault(collection, tokenId);

        // create a dynamic array of addresses that includes msg.sender and tokenIds that includes tokenId
        address[] memory participants = new address[](1);
        participants[0] = msg.sender;

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        bool isPublic = whitelist.length == 0;

        // register new raffle
        raffles[++raffleCounter] = Raffle({
            isPublic: isPublic,
            collection: collection,
            endingTime: timeLimit + block.timestamp,
            tokenIds: tokenIds,
            numberOfParticipants: numberOfParticipants,
            participantsList: participants,
            fees: fee,
            winner: addressZero,
            requested: false
        });

        // if its a private raffle, add msg.sender and whitelist list to raffleIdToWhitelisted mapping
        if (!isPublic) {
            raffleIdToWhitelisted[raffleCounter][msg.sender] = true;
            for (uint256 i = 0; i < whitelist.length; i++) {
                raffleIdToWhitelisted[raffleCounter][whitelist[i]] = true;
            }
        }

        emit RaffleCreated(
            raffleCounter, msg.sender, address(collection), timeLimit + block.timestamp, numberOfParticipants, isPublic
        );
    }

    // Transfer to Vault
    function _transferToVault(IERC721 collection, uint256 tokenId) internal {
        _transferNFT(collection, msg.sender, tokenId, address(this));
    }

    // Transfer an NFT from one address to another
    function _transferNFT(IERC721 collection, address from, uint256 tokenId, address to) internal {
        collection.safeTransferFrom(from, to, tokenId);
    }

    // Tansfer To winner
    function _transferToWinner(IERC721 collection, uint256[] memory tokenIds, address winner) internal {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _transferNFT(collection, address(this), tokenIds[i], winner);
        }
    }

    // VRF Callback
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        if (requests[_requestId].raffleId == 0) revert RequestNotFound();
        requests[_requestId].fulfilled = true;
        requests[_requestId].randomWord = _randomWords[0];

        _fulfillRaffle(_randomWords[0], requests[_requestId].raffleId);

        emit RequestFulfilled(_requestId, _randomWords[0]);
    }

    // Fulfill the raffle
    function _fulfillRaffle(uint256 randomNumber, uint256 raffleId) internal {
        Raffle storage raffle = raffles[raffleId];

        // Select random winner
        uint256 winnerIndex = randomNumber % raffle.participantsList.length;

        // set winner
        raffle.winner = raffle.participantsList[winnerIndex];

        // transfer NFTs to winner
        _transferToWinner(raffle.collection, raffle.tokenIds, raffle.participantsList[winnerIndex]);

        // add collectable fees
        collectableFees += raffles[raffleId].fees;

        emit RaffleResult(raffleId, raffle.participantsList[winnerIndex]);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

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
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

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
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/** ****************************************************************************
 * @notice Interface for contracts using VRF randomness
 * *****************************************************************************
 * @dev PURPOSE
 *
 * @dev Reggie the Random Oracle (not his real job) wants to provide randomness
 * @dev to Vera the verifier in such a way that Vera can be sure he's not
 * @dev making his output up to suit himself. Reggie provides Vera a public key
 * @dev to which he knows the secret key. Each time Vera provides a seed to
 * @dev Reggie, he gives back a value which is computed completely
 * @dev deterministically from the seed and the secret key.
 *
 * @dev Reggie provides a proof by which Vera can verify that the output was
 * @dev correctly computed once Reggie tells it to her, but without that proof,
 * @dev the output is indistinguishable to her from a uniform random sample
 * @dev from the output space.
 *
 * @dev The purpose of this contract is to make it easy for unrelated contracts
 * @dev to talk to Vera the verifier about the work Reggie is doing, to provide
 * @dev simple access to a verifiable source of randomness. It ensures 2 things:
 * @dev 1. The fulfillment came from the VRFCoordinator
 * @dev 2. The consumer contract implements fulfillRandomWords.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFConsumerBase, and can
 * @dev initialize VRFConsumerBase's attributes in their constructor as
 * @dev shown:
 *
 * @dev   contract VRFConsumer {
 * @dev     constructor(<other arguments>, address _vrfCoordinator, address _link)
 * @dev       VRFConsumerBase(_vrfCoordinator) public {
 * @dev         <initialization with other arguments goes here>
 * @dev       }
 * @dev   }
 *
 * @dev The oracle will have given you an ID for the VRF keypair they have
 * @dev committed to (let's call it keyHash). Create subscription, fund it
 * @dev and your consumer contract as a consumer of it (see VRFCoordinatorInterface
 * @dev subscription management functions).
 * @dev Call requestRandomWords(keyHash, subId, minimumRequestConfirmations,
 * @dev callbackGasLimit, numWords),
 * @dev see (VRFCoordinatorInterface for a description of the arguments).
 *
 * @dev Once the VRFCoordinator has received and validated the oracle's response
 * @dev to your request, it will call your contract's fulfillRandomWords method.
 *
 * @dev The randomness argument to fulfillRandomWords is a set of random words
 * @dev generated from your requestId and the blockHash of the request.
 *
 * @dev If your contract could have concurrent requests open, you can use the
 * @dev requestId returned from requestRandomWords to track which response is associated
 * @dev with which randomness request.
 * @dev See "SECURITY CONSIDERATIONS" for principles to keep in mind,
 * @dev if your contract could have multiple requests in flight simultaneously.
 *
 * @dev Colliding `requestId`s are cryptographically impossible as long as seeds
 * @dev differ.
 *
 * *****************************************************************************
 * @dev SECURITY CONSIDERATIONS
 *
 * @dev A method with the ability to call your fulfillRandomness method directly
 * @dev could spoof a VRF response with any random value, so it's critical that
 * @dev it cannot be directly called by anything other than this base contract
 * @dev (specifically, by the VRFConsumerBase.rawFulfillRandomness method).
 *
 * @dev For your users to trust that your contract's random behavior is free
 * @dev from malicious interference, it's best if you can write it so that all
 * @dev behaviors implied by a VRF response are executed *during* your
 * @dev fulfillRandomness method. If your contract must store the response (or
 * @dev anything derived from it) and use it later, you must ensure that any
 * @dev user-significant behavior which depends on that stored value cannot be
 * @dev manipulated by a subsequent VRF request.
 *
 * @dev Similarly, both miners and the VRF oracle itself have some influence
 * @dev over the order in which VRF responses appear on the blockchain, so if
 * @dev your contract could have multiple VRF requests in flight simultaneously,
 * @dev you must ensure that the order in which the VRF responses arrive cannot
 * @dev be used to manipulate your contract's user-significant behavior.
 *
 * @dev Since the block hash of the block which contains the requestRandomness
 * @dev call is mixed into the input to the VRF *last*, a sufficiently powerful
 * @dev miner could, in principle, fork the blockchain to evict the block
 * @dev containing the request, forcing the request to be included in a
 * @dev different block with a different hash, and therefore a different input
 * @dev to the VRF. However, such an attack would incur a substantial economic
 * @dev cost. This cost scales with the number of blocks the VRF oracle waits
 * @dev until it calls responds to a request. It is for this reason that
 * @dev that you can signal to an oracle you'd like them to wait longer before
 * @dev responding to the request (however this is not enforced in the contract
 * @dev and so remains effective only in the case of unmodified oracle software).
 */
abstract contract VRFConsumerBaseV2 {
  error OnlyCoordinatorCanFulfill(address have, address want);
  address private immutable vrfCoordinator;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   */
  constructor(address _vrfCoordinator) {
    vrfCoordinator = _vrfCoordinator;
  }

  /**
   * @notice fulfillRandomness handles the VRF response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @dev VRFConsumerBaseV2 expects its subcontracts to have a method with this
   * @dev signature, and will call it once it has verified the proof
   * @dev associated with the randomness. (It is triggered via a call to
   * @dev rawFulfillRandomness, below.)
   *
   * @param requestId The Id initially returned by requestRandomness
   * @param randomWords the VRF output expanded to the requested number of words
   */
  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual;

  // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
  // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
  // the origin of the call
  function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
    if (msg.sender != vrfCoordinator) {
      revert OnlyCoordinatorCanFulfill(msg.sender, vrfCoordinator);
    }
    fulfillRandomWords(requestId, randomWords);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface VRFCoordinatorV2Interface {
  /**
   * @notice Get configuration relevant for making requests
   * @return minimumRequestConfirmations global min for request confirmations
   * @return maxGasLimit global max for request gas limit
   * @return s_provingKeyHashes list of registered key hashes
   */
  function getRequestConfig() external view returns (uint16, uint32, bytes32[] memory);

  /**
   * @notice Request a set of random words.
   * @param keyHash - Corresponds to a particular oracle job which uses
   * that key for generating the VRF proof. Different keyHash's have different gas price
   * ceilings, so you can select a specific one to bound your maximum per request cost.
   * @param subId  - The ID of the VRF subscription. Must be funded
   * with the minimum subscription balance required for the selected keyHash.
   * @param minimumRequestConfirmations - How many blocks you'd like the
   * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
   * for why you may want to request more. The acceptable range is
   * [minimumRequestBlockConfirmations, 200].
   * @param callbackGasLimit - How much gas you'd like to receive in your
   * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
   * may be slightly less than this amount because of gas used calling the function
   * (argument decoding etc.), so you may need to request slightly more than you expect
   * to have inside fulfillRandomWords. The acceptable range is
   * [0, maxGasLimit]
   * @param numWords - The number of uint256 random values you'd like to receive
   * in your fulfillRandomWords callback. Note these numbers are expanded in a
   * secure way by the VRFCoordinator from a single random value supplied by the oracle.
   * @return requestId - A unique identifier of the request. Can be used to match
   * a request to a response in fulfillRandomWords.
   */
  function requestRandomWords(
    bytes32 keyHash,
    uint64 subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint256 requestId);

  /**
   * @notice Create a VRF subscription.
   * @return subId - A unique subscription id.
   * @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
   * @dev Note to fund the subscription, use transferAndCall. For example
   * @dev  LINKTOKEN.transferAndCall(
   * @dev    address(COORDINATOR),
   * @dev    amount,
   * @dev    abi.encode(subId));
   */
  function createSubscription() external returns (uint64 subId);

  /**
   * @notice Get a VRF subscription.
   * @param subId - ID of the subscription
   * @return balance - LINK balance of the subscription in juels.
   * @return reqCount - number of requests for this subscription, determines fee tier.
   * @return owner - owner of the subscription.
   * @return consumers - list of consumer address which are able to use this subscription.
   */
  function getSubscription(
    uint64 subId
  ) external view returns (uint96 balance, uint64 reqCount, address owner, address[] memory consumers);

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @param newOwner - proposed new owner of the subscription
   */
  function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner) external;

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @dev will revert if original owner of subId has
   * not requested that msg.sender become the new owner.
   */
  function acceptSubscriptionOwnerTransfer(uint64 subId) external;

  /**
   * @notice Add a consumer to a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - New consumer which can use the subscription
   */
  function addConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Remove a consumer from a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - Consumer to remove from the subscription
   */
  function removeConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Cancel a subscription
   * @param subId - ID of the subscription
   * @param to - Where to send the remaining LINK to
   */
  function cancelSubscription(uint64 subId, address to) external;

  /*
   * @notice Check to see if there exists a request commitment consumers
   * for all consumers and keyhashes for a given sub.
   * @param subId - ID of the subscription
   * @return true if there exists at least one unfulfilled request for the subscription, false
   * otherwise.
   */
  function pendingRequestExists(uint64 subId) external view returns (bool);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IRabbleRabble {
    // Raffle
    struct Raffle {
        bool isPublic;
        IERC721 collection;
        uint256 endingTime;
        uint256[] tokenIds;
        uint256 numberOfParticipants;
        address[] participantsList;
        uint256 fees;
        address winner;
        bool requested;
    }

    // Chainlink VRF request
    struct RequestStatus {
        uint256 raffleId;
        uint256 randomWord;
        bool fulfilled;
    }

    // Events

    event RaffleRequest(uint256 indexed raffleId, uint256 indexed requestId);
    event RequestFulfilled(uint256 indexed requestId, uint256 indexed randomWords);
    event RaffleResult(uint256 indexed raffleId, address winner);
    event RaffleCreated(
        uint256 indexed raffleId,
        address indexed creator,
        address indexed collection,
        uint256 timeLimit,
        uint256 numberOfParticipants,
        bool isPublic
    );
    event RaffleJoined(uint256 indexed raffleId, address indexed participant, uint256 indexed tokenId);
    event RaffleRefunded(uint256 indexed raffleId);
    event AddedToWhitelist(uint256 indexed raffleId, address[] accounts);

    // Errors

    error InvalidNumberOfParticipants();
    error EndingTimeReached();
    error UnableToWhitelist();
    error AlreadyFinalized();
    error InvalidTimelimit();
    error WrongMessageValue();
    error UnableToCollect();
    error RaffleNotActive();
    error RaffleIsPublic();
    error RaffleFull();
    error UnableToJoin();
    error AlreadyInRaffle();
    error NotOwnerOf();
    error RequestNotFound();
    error UnableToRefund();
    error Paused();
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
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC721/IERC721.sol)

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
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

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
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

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
    function transferFrom(address from, address to, uint256 tokenId) external;

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
    function setApprovalForAll(address operator, bool approved) external;

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