// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import "../src/Errors.sol";
import { BoutNonMappingInfo, BoutFighter, BoutState, MemeBuySize } from "../src/Objects.sol";
import { Wallet, TestBaseContract } from "./utils/TestBaseContract.sol";
import { LibConstants } from "../src/libs/LibConstants.sol";

contract MemeTest is TestBaseContract {
    uint fighterAId = 1;
    uint fighterBId = 2;

    function setUp() public override {
        super.setUp();
    }

    function testPurchaseMeme() public {
        // proxy.setAddress(LibConstants.MEME_TOKEN_ADDRESS, memeTokenAddress);
        // string memory rpcAlias = "polygon";
        // string memory rpcUrl = getChain(rpcAlias).rpcUrl;
        // vm.createSelectFork(rpcUrl);
        string memory mainnetUrl = vm.rpcUrl("polygon");
        uint256 mainnetFork = vm.createSelectFork(mainnetUrl, 38026803);

        // proxy.buyMeme(MemeBuySize.Five);
    }
}
