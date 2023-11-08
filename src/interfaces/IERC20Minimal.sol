pragma solidity ^0.8.19;

interface IERC20Minimal {
    function transferFrom(address from, address to, uint256 amount) external;
}