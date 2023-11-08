pragma solidity ^0.8.19;

interface IDBXeNFTFactory {
    function baseDBXeNFTPower(uint256 tokenId) external view returns(uint256);
}