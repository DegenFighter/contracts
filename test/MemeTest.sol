// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import "../src/Errors.sol";
import { BoutNonMappingInfo, BoutFighter, BoutState, MemeBuySizeDollars } from "../src/Objects.sol";
import { Wallet, TestBaseContract } from "./utils/TestBaseContract.sol";
import { LibConstants } from "../src/libs/LibConstants.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { MockTwap } from "../src/testing-only/MockTwap.sol";
import { LibTokenIds } from "../src/libs/LibToken.sol";

import { ChainDependent, returnChainDependentData } from "../src/ChainDependentData.sol";

/// @notice These tests first fork polygon mainnet. todo refactor fork tests to point to zksync mainnet once uniswap v3 is deployed there

contract MemeTest is TestBaseContract {
    address constant user1 = address(0x1);

    function setUp() public override {
        string memory mainnetUrl = vm.rpcUrl("polygon");
        uint256 mainnetFork = vm.createSelectFork(mainnetUrl);
        // uint256 mainnetFork = vm.createSelectFork(mainnetUrl, 38026803);
        vm.chainId(137);

        super.setUp();
    }

    // ------------------------------------------------------ //
    //
    // Buy MEME
    //
    // ------------------------------------------------------ //

    function testBuyMemeWithInsufficientCoin() public {
        vm.expectRevert();
        proxy.buyMeme(MemeBuySizeDollars.Five);
    }

    function testPurchaseMemeWithMockTwap() public {
        // deploy mock twap
        MockTwap twap = new MockTwap();

        twap.setSqrtPriceX96(1625 * 10 ** 18);
        proxy.setPriceOracle(address(twap));

        console2.log(address(this).balance);

        uint256 user1_startingBalance = user1.balance;

        vm.prank(user1);
        proxy.buyMeme{ value: 1 ether }(MemeBuySizeDollars.Five);
        uint256 user1_endingBalance = user1.balance;

        uint256 receiverBalance = server.addr.balance;

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

        console2.log(address(this).balance);

        // give more than 0.5 coin to server
        vm.deal(server.addr, 1 ether);

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
        ChainDependent memory cd = returnChainDependentData();
        proxy.setPriceOracle(cd.priceOracle);

        uint256 user1_startingBalance = user1.balance;

        vm.prank(user1);
        proxy.buyMeme{ value: 10 ether }(MemeBuySizeDollars.Five);
        uint256 user1_endingBalance = user1.balance;

        uint256 receiverBalance = server.addr.balance;

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

    function testFuzz_buyMeme(uint256 amount) public {
        amount = bound(amount, 1 ether, 1000 ether);

        MockTwap twap = new MockTwap();

        twap.setSqrtPriceX96(1625 * 10 ** 18);
        proxy.setPriceOracle(address(twap));

        vm.deal(user1, 1e6 ether);

        uint256 user1_startingBalance;

        uint256 server_startingBalance;
        uint256 treasury_startingBalance;

        uint256 user1_endingBalance;

        uint256 cost; // cost of meme in coin
        uint256 buyAmount; // amount of MEME bought
        uint256 server_endingBalance;
        uint256 treasury_endingBalance;

        MemeBuySizeDollars size;

        uint256 user1_startingMemeBalance;
        for (uint256 i; i < 5; ++i) {
            if (i == 0) {
                size = MemeBuySizeDollars.Five;
            } else if (i == 1) {
                size = MemeBuySizeDollars.Ten;
            } else if (i == 2) {
                size = MemeBuySizeDollars.Twenty;
            } else if (i == 3) {
                size = MemeBuySizeDollars.Fifty;
            } else if (i == 4) {
                size = MemeBuySizeDollars.Hundred;
            }
            user1_startingBalance = user1.balance;

            server_startingBalance = server.addr.balance;
            treasury_startingBalance = address(proxy).balance;

            user1_startingMemeBalance = proxy.tokenBalanceOf(LibTokenIds.TOKEN_MEME, user1);
            (cost, buyAmount) = proxy.getMemeCost(size);
            if (cost <= amount) {
                vm.prank(user1);
                proxy.buyMeme{ value: amount }(size);
                assertEq(
                    proxy.tokenBalanceOf(LibTokenIds.TOKEN_MEME, user1),
                    user1_startingMemeBalance + buyAmount,
                    "user1 meme balance should INCREASE"
                );
                assertEq(
                    memeToken.balanceOf(user1),
                    user1_startingMemeBalance + buyAmount,
                    "user1 meme balance should INCREASE"
                );
            } else {
                delete cost;
            }

            user1_endingBalance = user1.balance;

            server_endingBalance = server.addr.balance;
            treasury_endingBalance = address(proxy).balance;

            if (server_startingBalance > LibConstants.SERVER_COIN_TRESHOLD) {
                assertEq(
                    treasury_endingBalance,
                    treasury_startingBalance + cost,
                    "treasury balance should INCREASE by cost"
                );
                assertEq(
                    server_startingBalance,
                    server_endingBalance,
                    "server balance should NOT change"
                );
            } else {
                assertEq(
                    treasury_endingBalance,
                    treasury_startingBalance,
                    "treasury balance should NOT change"
                );
                assertEq(
                    server_endingBalance,
                    server_startingBalance + cost,
                    "server balance should INCREASE by cost"
                );
            }
        }
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
