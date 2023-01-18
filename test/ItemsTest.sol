// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import "src/Errors.sol";
import { BoutNonMappingInfo, BoutFighter, BoutState, MemeBuySizeDollars } from "src/Objects.sol";
import { Wallet, TestBaseContract } from "./utils/TestBaseContract.sol";
import { LibConstants, LibTokenIds } from "src/libs/LibConstants.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @notice These tests first fork polygon mainnet.

contract ItemsTest is TestBaseContract {
    uint fighterAId = 1;
    uint fighterBId = 2;

    function setUp() public override {
        string memory mainnetUrl = vm.rpcUrl("polygon");
        // uint256 mainnetFork = vm.createSelectFork(mainnetUrl);
        uint256 mainnetFork = vm.createSelectFork(mainnetUrl, 38026803);

        super.setUp();

        proxy.setAddress(LibConstants.TREASURY_ADDRESS, address(proxy));
        writeTokenBalance(address(this), address(proxy), LibConstants.WMATIC_POLYGON_ADDRESS, 10000e18);

        proxy.buyMeme(MemeBuySizeDollars.Hundred);
    }

    function testBuyItem() public {
        proxy.createItem(LibTokenIds.BROADCAST_MSG);

        proxy.buyItem(LibTokenIds.BROADCAST_MSG, 1);
    }
}
