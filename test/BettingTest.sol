// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { BytesLib } from "solidity-bytes-utils/BytesLib.sol";

import "forge-std/Test.sol";
import "../src/Errors.sol";
import { Bout, BoutFighter, BoutState } from "../src/Objects.sol";
import { Wallet, TestBaseContract } from "./utils/TestBaseContract.sol";
import { LibConstants } from "../src/libs/LibConstants.sol";
import { LibTokenIds } from "../src/libs/LibToken.sol";
import { LibBetting } from "../src/libs/LibBetting.sol";

contract BettingTest is TestBaseContract {
    // ------------------------------------------------------ //
    //
    // Finalize bouts
    //
    // ------------------------------------------------------ //

    function testFinalizeBoutsDataLength() public {
        BettingScenario memory scen = _getScenario_Default();

        assertEq(
            _buildFinalizedBoutData(1, scen).length,
            LibBetting.FINALIZE_CHUNK_BYTES_LEN,
            "invalid length"
        );
    }

    function testFinalizeBoutsMustBeDoneByServer() public {
        bytes memory data = _buildFinalizedBoutData(1, _getScenario_Default());

        address dummyServer = vm.addr(123);

        vm.prank(dummyServer);
        vm.expectRevert(CallerMustBeServerError.selector);
        proxy.finalizeBouts(1, data);

        proxy.setAddress(LibConstants.SERVER_ADDRESS, dummyServer);

        vm.prank(dummyServer);
        proxy.finalizeBouts(1, data);
    }

    function testFinalizeBoutsWithInvalidData() public {
        bytes memory data = _buildFinalizedBoutData(1, _getScenario_Default());

        bytes memory finalData = abi.encodePacked(
            data,
            uint8(99),
            BytesLib.slice(data, 1, data.length - 1)
        );

        vm.startPrank(server.addr);

        vm.expectRevert(abi.encodeWithSelector(InvalidFinalizedBoutDataError.selector, 99));
        proxy.finalizeBouts(2, finalData);

        vm.stopPrank();
    }

    function testFinalizeBoutsWithInvalidState() public {
        uint boutId = 123;

        bytes memory data = _buildFinalizedBoutData(boutId, _getScenario_Default());

        vm.startPrank(server.addr);

        // state: Finalized - fails
        proxy._testSetBoutState(boutId, BoutState.Finalized);
        vm.expectRevert(
            abi.encodeWithSelector(BoutInWrongStateError.selector, boutId, BoutState.Finalized)
        );
        proxy.finalizeBouts(1, data);

        vm.stopPrank();
    }

    function testFinalizeBoutsWithInvalidBettorData() public {
        uint boutId = 123;

        vm.startPrank(server.addr);

        BettingScenario memory scen_A = _getScenario_Default();
        scen_A.fighterAPot = 0;
        scen_A.fighterANumBettors = 1;
        bytes memory data_A = _buildFinalizedBoutData(boutId, scen_A);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidBettorDataError.selector, boutId, BoutFighter.FighterA)
        );
        proxy.finalizeBouts(1, data_A);

        BettingScenario memory scen_B = _getScenario_Default();
        scen_B.fighterBPot = 0;
        scen_B.fighterBNumBettors = 1;
        bytes memory data_B = _buildFinalizedBoutData(boutId, scen_B);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidBettorDataError.selector, boutId, BoutFighter.FighterB)
        );
        proxy.finalizeBouts(1, data_B);

        vm.stopPrank();
    }

    function testFinalizeBoutsWithInvalidWinner() public {
        uint boutId = 123;

        BettingScenario memory scen = _getScenario_Default();
        bytes memory data = _buildFinalizedBoutData(boutId, scen);
        data = abi.encodePacked(BytesLib.slice(data, 0, 77), uint8(5));

        vm.prank(server.addr);
        vm.expectRevert(abi.encodeWithSelector(InvalidWinnerError.selector, boutId, 5));
        proxy.finalizeBouts(1, data);
    }

    function testFinalizeBoutsUpdatesState() public {
        uint boutId = 123;

        BettingScenario memory scen = _getScenario_Default();
        bytes memory data = _buildFinalizedBoutData(boutId, scen);

        uint preTotalBouts = proxy.getTotalBouts();
        uint preFinalizedBouts = proxy.getTotalFinalizedBouts();

        vm.prank(server.addr);
        proxy.finalizeBouts(1, data);

        // check the state
        Bout memory bout = proxy.getBout(boutId);
        assertEq(bout.state, BoutState.Finalized, "state");
        assertGt(bout.finalizeTime, 0, "end time");
        assertEq(bout.winner, scen.winner, "winner");
        assertEq(bout.loser, scen.loser, "loser");
        assertEq(bout.fighterIds, scen.fighterIds, "fighter ids");
        assertEq(bout.fighterPots, scen.fighterPots, "fighter pots");
        assertEq(bout.fighterNumBettors, scen.fighterNumBettors, "fighter num bettors");

        // check global state
        assertEq(proxy.getTotalBouts(), preTotalBouts + 1, "total bouts");
        assertEq(proxy.getTotalFinalizedBouts(), preFinalizedBouts + 1, "finalized bouts");
        assertEq(proxy.getBoutIdByIndex(preTotalBouts + 1), boutId, "bout at index");
    }

    function testFinalizeMultiplesBoutsUpdatesState() public {
        BettingScenario[] memory scen = new BettingScenario[](3);
        bytes[] memory data = new bytes[](3);

        scen[0] = _getScenario_Default();
        data[0] = _buildFinalizedBoutData(123, scen[0]);

        scen[1] = _getScenario_AllOnLoser();
        data[1] = _buildFinalizedBoutData(456, scen[1]);

        scen[2] = _getScenario_AllOnWinner();
        data[2] = _buildFinalizedBoutData(789, scen[2]);

        vm.prank(server.addr);
        proxy.finalizeBouts(3, abi.encodePacked(data[0], data[1], data[2]));

        // check global state
        assertEq(proxy.getTotalBouts(), 3, "total bouts");
        assertEq(proxy.getTotalFinalizedBouts(), 3, "finalized bouts");

        for (uint i = 0; i < 3; i++) {
            uint boutId = 123 + (i * 333);
            assertEq(proxy.getBoutIdByIndex(i + 1), boutId, "bout at index");

            // check the state
            Bout memory bout = proxy.getBout(boutId);
            assertEq(bout.state, BoutState.Finalized, "state");
            assertGt(bout.finalizeTime, 0, "end time");
            assertEq(bout.winner, scen[i].winner, "winner");
            assertEq(bout.loser, scen[i].loser, "loser");
            assertEq(bout.fighterIds, scen[i].fighterIds, "fighter ids");
            assertEq(bout.fighterPots, scen[i].fighterPots, "fighter pots");
            assertEq(bout.fighterNumBettors, scen[i].fighterNumBettors, "fighter num bettors");
        }
    }

    function testFinalizeBoutsEmitsEvents() public {
        BettingScenario memory scen = _getScenario_Default();
        bytes memory data_1 = _buildFinalizedBoutData(123, scen);
        bytes memory data_2 = _buildFinalizedBoutData(124, scen);

        vm.recordLogs();

        vm.prank(server.addr);
        proxy.finalizeBouts(2, abi.encodePacked(data_1, data_2));

        // check logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(entries[0].topics.length, 1, "Invalid event count");
        assertEq(entries[0].topics[0], keccak256("BoutFinalized(uint256)"));
        uint eBoutId1 = abi.decode(entries[0].data, (uint));
        assertEq(eBoutId1, 123, "bout id incorrect");

        assertEq(entries[1].topics.length, 1, "Invalid event count");
        assertEq(entries[1].topics[0], keccak256("BoutFinalized(uint256)"));
        uint eBoutId2 = abi.decode(entries[1].data, (uint));
        assertEq(eBoutId2, 124, "bout id incorrect");
    }

    // ------------------------------------------------------ //
    //
    // Private/internal methods
    //
    // ------------------------------------------------------ //

    struct BettingScenario {
        uint[] fighterIds;
        uint fighterAId;
        uint fighterBId;
        uint[] fighterNumBettors;
        uint fighterANumBettors;
        uint fighterBNumBettors;
        uint[] fighterPots;
        uint fighterAPot;
        uint fighterBPot;
        BoutFighter winner;
        BoutFighter loser;
    }

    function _buildFinalizedBoutData(
        uint boutId,
        BettingScenario memory scen
    ) internal pure returns (bytes memory) {
        return
            LibBetting.buildFinalizedBoutData(
                boutId,
                scen.fighterAId,
                scen.fighterBId,
                scen.fighterANumBettors,
                scen.fighterBNumBettors,
                scen.fighterAPot,
                scen.fighterBPot,
                scen.winner
            );
    }

    // 5 playres, 2 bet on winner, 3 on loser
    function _getScenario_Default() internal returns (BettingScenario memory scen) {
        scen.winner = BoutFighter.FighterB;
        scen.loser = BoutFighter.FighterA;
        scen.fighterANumBettors = 3;
        scen.fighterBNumBettors = 2;
        scen.fighterAPot = 100;
        scen.fighterBPot = 200;
        scen = _finalizeScenario(scen);
    }

    // 5 players, all bet on the loser
    function _getScenario_AllOnLoser() internal returns (BettingScenario memory scen) {
        scen.winner = BoutFighter.FighterB;
        scen.loser = BoutFighter.FighterA;
        scen.fighterANumBettors = 5;
        scen.fighterBNumBettors = 0;
        scen.fighterAPot = 100;
        scen.fighterBPot = 0;
        scen = _finalizeScenario(scen);
    }

    // 5 players, all bet on the winner
    function _getScenario_AllOnWinner() internal returns (BettingScenario memory scen) {
        scen.winner = BoutFighter.FighterB;
        scen.loser = BoutFighter.FighterA;
        scen.fighterANumBettors = 0;
        scen.fighterBNumBettors = 5;
        scen.fighterAPot = 0;
        scen.fighterBPot = 200;
        scen = _finalizeScenario(scen);
    }

    function _finalizeScenario(
        BettingScenario memory scen
    ) internal returns (BettingScenario memory) {
        scen.fighterAId = 21;
        scen.fighterBId = 22;

        scen.fighterIds = new uint[](2);
        scen.fighterIds[0] = scen.fighterAId;
        scen.fighterIds[1] = scen.fighterBId;

        scen.fighterPots = new uint[](2);
        scen.fighterPots[0] = scen.fighterAPot;
        scen.fighterPots[1] = scen.fighterBPot;

        scen.fighterNumBettors = new uint[](2);
        scen.fighterNumBettors[0] = scen.fighterANumBettors;
        scen.fighterNumBettors[1] = scen.fighterBNumBettors;

        return scen;
    }
}
