// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title IERC5114
 * @dev Interface for ERC5114 Soulbound Badge standard
 */
interface IERC5114 {
    event Mint(uint256 indexed badgeId, address indexed nftAddress, uint256 indexed nftTokenId);
    
    function ownerOf(uint256 badgeId) external view returns (address nftAddress, uint256 nftTokenId);
    function collectionUri() external pure returns (string memory);
    function badgeUri(uint256 badgeId) external view returns (string memory);
    function metadataFormat() external pure returns (string memory);
}

/**
 * @title ERC5114 Soulbound Badge
 * @dev Implementation of ERC5114 - A badge bound to an NFT at mint time that cannot be transferred
 */
contract ERC5114 is IERC5114, Ownable, ERC165 {
    // Mapping from badge ID to owner NFT details
    mapping(uint256 => NFTIdentifier) private _owners;
    
    // Mapping to track if a badge has been minted
    mapping(uint256 => bool) private _minted;
    
    // IPFS URI for collection metadata
    string private immutable _collectionUri;
    
    // Mapping from badge ID to badge-specific IPFS URI
    mapping(uint256 => string) private _badgeUris;
    
    struct NFTIdentifier {
        address nftAddress;
        uint256 nftTokenId;
    }
    
    /**
     * @dev Constructor sets the collection URI
     * @param collectionUri_ IPFS URI for collection metadata
     */
    constructor(string memory collectionUri_) {
        require(
            _isIpfsUri(collectionUri_),
            "ERC5114: Collection URI must be IPFS"
        );
        _collectionUri = collectionUri_;
    }
    
    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC5114).interfaceId ||
            super.supportsInterface(interfaceId);
    }
    
    /**
     * @dev Mints a new badge bound to an NFT
     * @param badgeId The ID of the badge to mint
     * @param nftAddress The address of the NFT contract this badge is bound to
     * @param nftTokenId The token ID of the NFT this badge is bound to
     * @param badgeUri_ IPFS URI for badge-specific metadata
     */
    function mint(
        uint256 badgeId,
        address nftAddress,
        uint256 nftTokenId,
        string calldata badgeUri_
    ) external onlyOwner {
        require(!_minted[badgeId], "ERC5114: Badge already minted");
        require(nftAddress != address(0), "ERC5114: Invalid NFT address");
        require(
            _isIpfsUri(badgeUri_),
            "ERC5114: Badge URI must be IPFS"
        );
        
        // Verify NFT exists
        try IERC721(nftAddress).ownerOf(nftTokenId) returns (address) {
            // NFT exists, proceed with minting
        } catch {
            revert("ERC5114: NFT does not exist");
        }
        
        _minted[badgeId] = true;
        _owners[badgeId] = NFTIdentifier(nftAddress, nftTokenId);
        _badgeUris[badgeId] = badgeUri_;
        
        emit Mint(badgeId, nftAddress, nftTokenId);
    }
    
    /**
     * @dev Returns the NFT that this badge is bound to
     * @param badgeId The ID of the badge
     * @return nftAddress The address of the NFT contract
     * @return nftTokenId The token ID of the NFT
     */
    function ownerOf(uint256 badgeId) external view override returns (address nftAddress, uint256 nftTokenId) {
        require(_minted[badgeId], "ERC5114: Badge not minted");
        NFTIdentifier memory owner = _owners[badgeId];
        return (owner.nftAddress, owner.nftTokenId);
    }
    
    /**
     * @dev Returns the collection URI
     * @return Collection metadata URI
     */
    function collectionUri() external pure override returns (string memory) {
        return _collectionUri;
    }
    
    /**
     * @dev Returns the badge-specific URI
     * @param badgeId The ID of the badge
     * @return Badge metadata URI
     */
    function badgeUri(uint256 badgeId) external view override returns (string memory) {
        require(_minted[badgeId], "ERC5114: Badge not minted");
        return _badgeUris[badgeId];
    }
    
    /**
     * @dev Returns the metadata format identifier
     * @return format The format identifier string
     */
    function metadataFormat() external pure override returns (string memory) {
        return "ERC5114-JSON-V1";
    }
    
    /**
     * @dev Validates if a URI is an IPFS URI
     * @param uri URI to validate
     * @return bool indicating if the URI is valid IPFS
     */
    function _isIpfsUri(string memory uri) private pure returns (bool) {
        bytes memory uriBytes = bytes(uri);
        return uriBytes.length >= 7 && 
               uriBytes[0] == "i" &&
               uriBytes[1] == "p" &&
               uriBytes[2] == "f" &&
               uriBytes[3] == "s" &&
               uriBytes[4] == ":" &&
               uriBytes[5] == "/" &&
               uriBytes[6] == "/";
    }
}