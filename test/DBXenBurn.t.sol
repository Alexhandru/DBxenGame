// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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
    address public DXN = 0x80f0C1c49891dcFDD40b6e0F960F84E6042bcB6F;
    address public DXN_WETH9_Pool = 0x7F808fD904FFA3eb6A6F259e6965Fb1466A05372;
    address public WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    NFTRegistry public nftRegistry;
    IERC721Minimal public nftContract;
    address public nftContractAddress = 0xA06735da049041eb523Ccf0b8c3fB9D36216c646;
    uint256 public initialBalance = 1 ether;
    uint256 mainnetFork;
    XenGame public xenGameInstance;
    PlayerNameRegistry public playerNameRegistry;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);

        playerNameRegistry = new PlayerNameRegistry(payable(address(4)), payable(address(5)));
        nftRegistry = new NFTRegistry(nftContractAddress);
        XenBurnInstance = new xenBurn(DXN, address(playerNameRegistry));
        xenGameInstance =
            new XenGame(nftContractAddress, address(nftRegistry), address(XenBurnInstance), address(playerNameRegistry));


        
        console.log("setup ran");
    }

    // function testCanGetPoolQuote() public {
    //     // select the fork
    //    uint256 amountOut = _getQuote(1 ether);
    //    console.log("Quote", amountOut);
    //    assertGt(amountOut, 0);
    // }

    function testOneEtherBurn() public {
        address xenGameMock = makeAddr("xenGame");
        vm.deal(xenGameMock, 2 ether);

        vm.startPrank(xenGameMock);
        XenBurnInstance.deposit{value: 1 ether}();
        vm.stopPrank();

        address user = makeAddr("alice");
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

        uint256 expectedOut = _getQuote(1 ether);
        uint256 minExpectedOut = (90 * expectedOut) / 100;

        XenBurnInstance.burnDXN();

        vm.stopPrank();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[3].topics[0], keccak256("Swap(address,address,int256,int256,uint160,uint128,int24)"));
        //assertGe(int256(entries[3].topics[4]), int256(minExpectedOut));
    }

    function _getQuote(uint128 amountIn) public view returns(uint256 amountOut) {
        (int24 tick, ) = OracleLibrary.consult(DXN_WETH9_Pool, 1);
        amountOut = OracleLibrary.getQuoteAtTick(tick, amountIn, WETH9, DXN);
    }
}