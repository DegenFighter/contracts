// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { Vm } from "forge-std/Vm.sol";
import { TestBaseContract } from "./utils/TestBaseContract.sol";

contract SettingsTest is TestBaseContract {
    function setUp() public override {
        super.setUp();
    }

    function testSetAddressBadAuth() public {
        Vm.prank(address(0));
        Vm.expectRevert("Not server");
        proxy.setAddress("test", address(0));
    }
}
