// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import "../src/Errors.sol";
import { BoutNonMappingInfo, BoutFighter, BoutState, MemeBuySizeDollars } from "../src/Objects.sol";
import { Wallet, TestBaseContract } from "./utils/TestBaseContract.sol";
import { LibConstants } from "../src/libs/LibConstants.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @notice These tests first fork polygon mainnet.

contract MemeTest is TestBaseContract {
    uint fighterAId = 1;
    uint fighterBId = 2;

    function setUp() public override {
        string memory mainnetUrl = vm.rpcUrl("polygon");
        // uint256 mainnetFork = vm.createSelectFork(mainnetUrl);
        uint256 mainnetFork = vm.createSelectFork(mainnetUrl, 38026803);

        super.setUp();
    }

    // ------------------------------------------------------ //
    //
    // Buy MEME
    //
    // ------------------------------------------------------ //

    function testBuyMemeWithInsufficientWMatic() public {
        proxy.setAddress(LibConstants.TREASURY_ADDRESS, address(proxy));

        IERC20 wmatic = IERC20(LibConstants.WMATIC_POLYGON_ADDRESS);

        vm.expectRevert();
        proxy.buyMeme(MemeBuySizeDollars.Five);
    }

    function testZkSyncMockPurchaseMeme() public {
        proxy.setAddress(LibConstants.TREASURY_ADDRESS, address(proxy));

        console2.log(address(this).balance);

        address user1 = address(0x1);

        uint256 user1_startingBalance = user1.balance;

        vm.prank(user1);
        proxy.buyMeme{ value: 1 ether }(MemeBuySizeDollars.Five);
        uint256 user1_endingBalance = user1.balance;

        uint256 receiverBalance = address(proxy.getAddress(LibConstants.SERVER_ADDRESS)).balance;

        assertEq(
            user1_startingBalance,
            user1_endingBalance + receiverBalance,
            "user1 balance is not correct"
        );
    }

    function testPurchaseMeme() public {
        proxy.setAddress(LibConstants.TREASURY_ADDRESS, address(proxy));
        writeTokenBalance(
            address(this),
            address(proxy),
            LibConstants.WMATIC_POLYGON_ADDRESS,
            10000e18
        );

        IERC20 wmatic = IERC20(LibConstants.WMATIC_POLYGON_ADDRESS);

        uint256 prevBal = wmatic.balanceOf(address(this));
        proxy.buyMeme(MemeBuySizeDollars.Five);

        uint256 newBal = wmatic.balanceOf(address(this));
        console2.log("new balance", newBal);
        assertEq(memeToken.balanceOf(address(this)), 1000 ether);

        uint256 balProxy = wmatic.balanceOf(address(proxy));
        assertEq(newBal + balProxy, prevBal, "wmatic balances are not correct");

        // todo add more checks
        proxy.buyMeme(MemeBuySizeDollars.Ten);
        proxy.buyMeme(MemeBuySizeDollars.Twenty);
        proxy.buyMeme(MemeBuySizeDollars.Fifty);
        proxy.buyMeme(MemeBuySizeDollars.Hundred);
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
