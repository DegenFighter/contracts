// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import "../src/Errors.sol";
import { BoutNonMappingInfo, BoutFighter, BoutState, MemeBuySizeDollars } from "../src/Objects.sol";
import { Wallet, TestBaseContract } from "./utils/TestBaseContract.sol";
import { LibConstants } from "../src/libs/LibConstants.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { MockTwap } from "../src/testing-only/MockTwap.sol";

import { ChainDependent, returnChainDependentData } from "../src/ChainDependentData.sol";

/// @notice These tests first fork polygon mainnet. todo refactor fork tests to point to zksync mainnet once uniswap v3 is deployed there

contract MemeTest is TestBaseContract {
    uint fighterAId = 1;
    uint fighterBId = 2;

    address SERVER_ADDRESS;

    function setUp() public override {
        string memory mainnetUrl = vm.rpcUrl("polygon");
        uint256 mainnetFork = vm.createSelectFork(mainnetUrl);
        // uint256 mainnetFork = vm.createSelectFork(mainnetUrl, 38026803);
        vm.chainId(137);

        super.setUp();

        SERVER_ADDRESS = proxy.getAddress(LibConstants.SERVER_ADDRESS);
    }

    // ------------------------------------------------------ //
    //
    // Buy MEME
    //
    // ------------------------------------------------------ //

    function testBuyMemeWithInsufficientCoin() public {
        proxy.setAddress(LibConstants.TREASURY_ADDRESS, address(proxy));

        vm.expectRevert();
        proxy.buyMeme(MemeBuySizeDollars.Five);
    }

    function testZkSyncMockPurchaseMeme() public {
        // deploy mock twap
        MockTwap twap = new MockTwap();

        twap.setSqrtPriceX96(1625 * 10 ** 18);
        proxy.setPriceOracle(address(twap));

        proxy.setAddress(LibConstants.TREASURY_ADDRESS, address(proxy));

        console2.log(address(this).balance);

        address user1 = address(0x1);

        uint256 user1_startingBalance = user1.balance;

        vm.prank(user1);
        proxy.buyMeme{ value: 1 ether }(MemeBuySizeDollars.Five);
        uint256 user1_endingBalance = user1.balance;

        uint256 receiverBalance = address(SERVER_ADDRESS).balance;

        console2.log("receiver balance", receiverBalance);
        console2.log("user1 ending balance", user1_endingBalance);
        assertEq(
            user1_startingBalance,
            user1_endingBalance + receiverBalance,
            "user1 balance is not correct"
        );

        assertEq(memeToken.balanceOf(user1), 1000 ether);
    }

    function testPurchaseMemeRoutingEthToTreasury() public {
        // deploy mock twap
        MockTwap twap = new MockTwap();

        twap.setSqrtPriceX96(1625 * 10 ** 18);
        proxy.setPriceOracle(address(twap));

        proxy.setAddress(LibConstants.TREASURY_ADDRESS, address(proxy));

        console2.log(address(this).balance);

        address user1 = address(0x1);

        // give more than 0.5 coin to server
        vm.deal(SERVER_ADDRESS, 1 ether);

        uint256 startingUserBalance = address(user1).balance;
        vm.prank(user1);
        proxy.buyMeme{ value: 1 ether }(MemeBuySizeDollars.Five);

        uint256 treasuryBalance = address(proxy).balance;

        assertEq(
            user1.balance + treasuryBalance,
            startingUserBalance,
            "treasury balance is not correct"
        );
    }

    function testPurchaseMemeWithLiveTwap() public {
        proxy.setAddress(LibConstants.TREASURY_ADDRESS, address(proxy));

        ChainDependent memory cd = returnChainDependentData();
        proxy.setPriceOracle(cd.priceOracle);

        address user1 = address(0x1);

        uint256 user1_startingBalance = user1.balance;

        vm.prank(user1);
        proxy.buyMeme{ value: 10 ether }(MemeBuySizeDollars.Five);
        uint256 user1_endingBalance = user1.balance;

        uint256 receiverBalance = address(proxy.getAddress(LibConstants.SERVER_ADDRESS)).balance;

        console2.log("receiver balance", receiverBalance);
        console2.log("user1 ending balance", user1_endingBalance);
        assertEq(
            user1_startingBalance,
            user1_endingBalance + receiverBalance,
            "user1 balance is not correct"
        );

        assertEq(memeToken.balanceOf(user1), 1000 ether);

        // todo add more checks
        // proxy.buyMeme{ value: 20 ether }(MemeBuySizeDollars.Ten);
        // proxy.buyMeme{ value: 30 ether }(MemeBuySizeDollars.Twenty);
        // proxy.buyMeme{ value: 70 ether }(MemeBuySizeDollars.Fifty);
        // proxy.buyMeme{ value: 200 ether }(MemeBuySizeDollars.Hundred);
    }

    // ------------------------------------------------------ //
    //
    // Claim MEME
    //
    // ------------------------------------------------------ //

    function testClaimMemeGivesUptoMinBetAmount() public {
        assertEq(memeToken.balanceOf(players[0].addr), 0);

        vm.prank(players[0].addr);
        proxy.claimFreeMeme();

        assertEq(memeToken.balanceOf(players[0].addr), LibConstants.MIN_BET_AMOUNT);

        uint amt = LibConstants.MIN_BET_AMOUNT / 3;
        proxy._testMintMeme(players[1].addr, amt);
        assertEq(memeToken.balanceOf(players[1].addr), amt);

        vm.prank(players[1].addr);
        proxy.claimFreeMeme();

        assertEq(memeToken.balanceOf(players[1].addr), LibConstants.MIN_BET_AMOUNT);
    }

    function testClaimMemeDoesNothingIfBalanceAlreadyEnough() public {
        uint amt = LibConstants.MIN_BET_AMOUNT;
        proxy._testMintMeme(players[0].addr, amt);
        assertEq(memeToken.balanceOf(players[0].addr), amt);

        vm.prank(players[0].addr);
        proxy.claimFreeMeme();

        assertEq(memeToken.balanceOf(players[0].addr), amt);
    }
}
