// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import { TestBaseContract } from "./utils/TestBaseContract.sol";

contract SettingsTest is TestBaseContract {
    function setUp() public override {
        super.setUp();
    }

    function testSetAddressBadAuth() public {
        vm.prank(address(0));
        vm.expectRevert(ERROR_MUST_BE_ADMIN);
        proxy.setAddress("test", address(0));
    }

    function testSetAddress() public {
        assertEq(proxy.getAddress("test"), address(0));

        proxy.setAddress("test", account0);

        assertEq(proxy.getAddress("test"), account0);

        proxy.setAddress("test", address(0));

        assertEq(proxy.getAddress("test"), address(0));
    }
}
