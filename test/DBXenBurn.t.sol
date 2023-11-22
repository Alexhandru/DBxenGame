// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/NFTRegistry.sol";
import "../src/xenBurn.sol";
import "../src/PlayerNameRegistry.sol";
import "../src/DBXenGame.sol";
import "../src/interfaces/IERC721Minimal.sol";
import "../src/interfaces/IWETH9Minimal.sol";

contract DBXenBurnTest is Test {
    xenBurn public XenBurnInstance;
    XenGame public xenGameInstance;
    PlayerNameRegistry public playerNameRegistry;
    NFTRegistry public nftRegistry;
    IERC721Minimal public nftContract;

    address public DXN = 0x80f0C1c49891dcFDD40b6e0F960F84E6042bcB6F;
    address public DXN_WETH9_Pool = 0x7F808fD904FFA3eb6A6F259e6965Fb1466A05372;
    address public WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public immutable BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public nftContractAddress = 0xA06735da049041eb523Ccf0b8c3fB9D36216c646;
    address public xenGameMock;
    address public user;

    uint256 public initialBalance = 1 ether;
    uint256 mainnetFork;
    
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() external {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);

        playerNameRegistry = new PlayerNameRegistry(payable(address(4)), payable(address(5)));
        nftRegistry = new NFTRegistry(nftContractAddress);
        XenBurnInstance = new xenBurn(DXN, address(playerNameRegistry));
        xenGameInstance =
            new XenGame(nftContractAddress, address(nftRegistry), address(XenBurnInstance), address(playerNameRegistry));

        xenGameMock = makeAddr("xenGame");
        vm.deal(xenGameMock, 100002 ether);
        
        console.log("setup ran");
    }

    function testOneEtherBurn() external {
        vm.startPrank(xenGameMock);
        XenBurnInstance.deposit{value: 1 ether}();
        vm.stopPrank();

        user = msg.sender;
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        try playerNameRegistry.registerPlayerName{value: 20000000000000000}(user, "Alice") {
            string memory name = playerNameRegistry.getPlayerFirstName(user);
            console.log("Registered name:", name);

            } catch Error(string memory reason) {
                fail(reason);
            } catch (bytes memory) /*lowLevelData*/ {
                fail("Low level error on registering name");
        }

        vm.recordLogs();

        uint256 expectedOut = _getQuote(1 ether * 98 / 100);
        uint256 minExpectedOut = (90 * expectedOut) / 100;

        uint256 userBalanceBefore = user.balance;
        uint256 burnAddressDXNBalanceBefore = IERC20(DXN).balanceOf(BURN_ADDRESS);

        XenBurnInstance.burnDXN();

        vm.stopPrank();

        uint256 userBalanceAfter = user.balance;
        uint256 burnAddressDXNBalanceAfter = IERC20(DXN).balanceOf(BURN_ADDRESS);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[3].topics[0], keccak256("Swap(address,address,int256,int256,uint160,uint128,int24)"));
        assertGe(burnAddressDXNBalanceAfter - burnAddressDXNBalanceBefore, minExpectedOut);
        assertEq(userBalanceAfter - userBalanceBefore, 1 ether / 100);
        assertEq(address(XenBurnInstance).balance, 1 ether / 100);
    }

    function test_TooLittleDXNReceived() external {
        vm.startPrank(xenGameMock);
        XenBurnInstance.deposit{value: 100000 ether}();
        vm.stopPrank();

        user = msg.sender;
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        playerNameRegistry.registerPlayerName{value: 20000000000000000}(user, "Alice");

        vm.expectRevert("Too little received");
        XenBurnInstance.burnDXN();
    }

    function testFuzz_buyBurn_LowBalance(uint256 amount) external {
        amount = bound(amount, 3, 10);
        console.log(amount);

        vm.startPrank(xenGameMock);
        XenBurnInstance.deposit{value: amount}();
        vm.stopPrank();

        user = msg.sender;
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        playerNameRegistry.registerPlayerName{value: 20000000000000000}(user, "Alice");

        vm.expectRevert("Too little received");
        XenBurnInstance.burnDXN();
    }

    function _getQuote(uint128 amountIn) internal view returns(uint256 amountOut) {
        (int24 tick, ) = OracleLibrary.consult(DXN_WETH9_Pool, 1);
        amountOut = OracleLibrary.getQuoteAtTick(tick, amountIn, WETH9, DXN);
    }
}