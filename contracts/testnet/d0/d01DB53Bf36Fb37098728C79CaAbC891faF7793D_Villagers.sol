// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./Ownable.sol";
import "./ERC721A.sol";
import "./ReentrancyGuard.sol";
import "./Strings.sol";


contract Villagers is ERC721A, Ownable, ReentrancyGuard {

    string public baseUri = "ipfs://QmUxisADfu7rbs7kRxsTxwq6DatVyiki19JJfdi24CCzYb/";

    bool public mintEnabled = true;
    bool public permDisabled = false;

    mapping(address => bool) public mintedFree;

    constructor() ERC721A("Villager", "VILLAG") {

    }

    function mintNormal() external nonReentrant {
        require(mintEnabled, "Mint disabled");
        require(msg.sender == tx.origin, "EOA only");
        require(!mintedFree[msg.sender], "Already minted free");

        mintedFree[msg.sender] = true;

        _mint(msg.sender, 1);
    }

    function setMintState(bool state) public onlyOwner {
        require(!permDisabled, "Mint has been disabled forever");
        mintEnabled = state;
    }

    function foreverDisableMint() public onlyOwner {
        permDisabled = true;
        mintEnabled = false;
    }

    function mintAdmin(uint256[] calldata amount, address[] calldata wallet) external payable onlyOwner {
        require(mintEnabled, "Mint disabled");

        for(uint256 i = 0; i < wallet.length; i++)
            _mint(wallet[i], amount[i]);
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal override {

        if(from == address(0)) {
            super._beforeTokenTransfers(from, to, startTokenId, quantity);
            return;
        }

        revert("Token is soulbound");
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {

		return string(abi.encodePacked(baseUri, Strings.toString(tokenId), ".json"));
	}

    function setBaseUri(string memory uri) public onlyOwner {
        baseUri = uri;
    }

    function withdraw() public payable onlyOwner {
        (bool success, ) = payable(msg.sender).call {value: address(this).balance}("");
        require(success);
    }

}