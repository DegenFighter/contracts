// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import "../src/Errors.sol";
import { TestBaseContract } from "./utils/TestBaseContract.sol";

contract SettingsTest is TestBaseContract {
    function setUp() public override {
        super.setUp();
    }

    function testSetAddressMustBeDoneByAdmin() public {
        vm.prank(address(0));
        vm.expectRevert(CallerMustBeAdminError.selector);
        proxy.setAddress("test", address(0));
    }

    function testSetAddress() public {
        assertEq(proxy.getAddress("test"), address(0));

        proxy.setAddress("test", account0);

        assertEq(proxy.getAddress("test"), account0);
    }
}
