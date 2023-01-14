// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import "../src/Errors.sol";
import { BoutNonMappingInfo, BoutFighter, BoutState, MemeBuySize } from "../src/Objects.sol";
import { Wallet, TestBaseContract } from "./utils/TestBaseContract.sol";
import { LibConstants } from "../src/libs/LibConstants.sol";
import { LibERC20 } from "src/erc20/LibERC20.sol";

/// @notice These tests first fork polygon mainnet.

contract MemeTest is TestBaseContract {
    uint fighterAId = 1;
    uint fighterBId = 2;

    function setUp() public override {
        string memory mainnetUrl = vm.rpcUrl("polygon");
        uint256 mainnetFork = vm.createSelectFork(mainnetUrl);
        // uint256 mainnetFork = vm.createSelectFork(mainnetUrl, 38026803);

        super.setUp();
    }

    function testPurchaseMeme() public {
        // proxy.setAddress(LibConstants.MEME_TOKEN_ADDRESS, memeTokenAddress);
        writeTokenBalance(address(this), address(proxy), LibConstants.WMATIC_POLYGON_ADDRESS, 10000e18);

        LibERC20.balanceOf(LibConstants.WMATIC_POLYGON_ADDRESS, address(this));
        proxy.buyMeme(MemeBuySize.Five);
        // proxy.buyMeme(MemeBuySize.Ten);
        // proxy.buyMeme(MemeBuySize.Twenty);
        // proxy.buyMeme(MemeBuySize.Fifty);
        // proxy.buyMeme(MemeBuySize.Hundred);
    }
}
