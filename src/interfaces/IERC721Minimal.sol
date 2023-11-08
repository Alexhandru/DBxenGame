pragma solidity ^0.8.19;

interface IERC721Minimal {
    function ownerOf(uint256 tokenId) external view returns(address);
}