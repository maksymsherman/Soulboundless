// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SoulboundToken is ERC721, Ownable {
    constructor() ERC721("SoulboundToken", "SBT") Ownable(msg.sender) {
    }
    
    event SoulboundTokenMinted(address indexed to, uint256 indexed tokenId);

    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        revert("This token is non-transferable");
    }

    function approve(address to, uint256 tokenId) public virtual override {
        revert("This token is non-transferable");
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        revert("This token is non-transferable");
    }

    function mint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
        emit SoulboundTokenMinted(to, tokenId);
    }
}