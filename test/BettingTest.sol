// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import { BoutNonMappingInfo, BoutParticipant, BoutState } from "../src/Base.sol";
import { TestBaseContract } from "./utils/TestBaseContract.sol";
import { LibConstants } from "../src/libs/LibConstants.sol";

contract Supporters is TestBaseContract {
    uint fighterAId = 1;
    uint fighterBId = 2;

    function setUp() public override {
        super.setUp();
    }

    function testCreateBoutMustBeDoneByServer() public {
        vm.prank(address(0));
        vm.expectRevert(ERROR_MUST_BE_SERVER);
        proxy.createBout(fighterAId, fighterBId);

        proxy.setAddress(LibConstants.SERVER_ADDRESS, address(0));

        vm.prank(address(0));
        proxy.createBout(fighterAId, fighterBId);
    }

    function testCreateBout() public {
        assertEq(proxy.getTotalBouts(), 0, "no bouts");

        // create and check event
        vm.recordLogs();
        proxy.createBout(fighterAId, fighterBId);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1, "Invalid event count");
        assertEq(entries[0].topics[0], keccak256("BoutCreated(uint256)"));
        uint boutNum = abi.decode(entries[0].data, (uint256));
        assertEq(boutNum, 1, "Event boutNum incorrect");

        // check bout count updated
        assertEq(proxy.getTotalBouts(), 1, "1 bout");

        // check basic bout info
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(1);
        assertEq(bout.id, 1, "bout id");
        assertEq(uint(bout.state), uint(BoutState.Created), "created");
        assertEq(uint(bout.winner), uint(BoutParticipant.Unknown), "winner not set");
        assertEq(uint(bout.loser), uint(BoutParticipant.Unknown), "loser not set");

        // check bout fighters
        assertEq(proxy.getBoutFighterId(1, BoutParticipant.FighterA), fighterAId, "fighterAId");
        assertEq(proxy.getBoutFighterId(1, BoutParticipant.FighterB), fighterBId, "fighterBId");
    }
}
