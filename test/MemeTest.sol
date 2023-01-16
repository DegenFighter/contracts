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

    function testPurchaseMeme() public {
        proxy.setAddress(LibConstants.TREASURY_ADDRESS, address(proxy));
        writeTokenBalance(address(this), address(proxy), LibConstants.WMATIC_POLYGON_ADDRESS, 10000e18);

        IERC20 wmatic = IERC20(LibConstants.WMATIC_POLYGON_ADDRESS);

        wmatic.balanceOf(address(this));
        proxy.buyMeme(MemeBuySizeDollars.Five);

        assertEq(memeToken.balanceOf(address(this)), 1000 ether);
        // proxy.buyMeme(MemeBuySizeDollars.Ten);
        // proxy.buyMeme(MemeBuySizeDollars.Twenty);
        // proxy.buyMeme(MemeBuySizeDollars.Fifty);
        // proxy.buyMeme(MemeBuySizeDollars.Hundred);
    }
}
