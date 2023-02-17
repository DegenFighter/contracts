// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import "../src/Errors.sol";
import { BoutFighter, BoutState } from "../src/Objects.sol";
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

    function testFinalizeBoutsMustBeDoneByServer() public {
        uint boutId = 1;
        BettingScenario memory scen = _getScenario_Default();
        bytes memory data = _buildFinalizedBoutData(boutId, scen);

        address dummyServer = vm.addr(123);

        vm.prank(dummyServer);
        vm.expectRevert(CallerMustBeServerError.selector);
        proxy.finalizeBouts(1, data);

        proxy.setAddress(LibConstants.SERVER_ADDRESS, dummyServer);

        vm.prank(dummyServer);
        proxy.finalizeBouts(1, data);
    }

    // function testFinalizeBoutsWithInvalidState() public {
    //     uint boutId = testBetMultiple();

    //     BettingScenario memory scen = _getScenario_Default();

    //     vm.startPrank(server.addr);

    //     // state: Ended - fails
    //     proxy._testSetBoutState(boutId, BoutState.Ended);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(BoutInWrongStateError.selector, boutId, BoutState.Ended)
    //     );
    //     proxy.finalizeBouts(
    //         boutId,
    //         21,
    //         22,
    //         scen.fighterAPot,
    //         scen.fighterBPot,
    //         scen.winner,
    //         scen.revealValues
    //     );

    //     vm.stopPrank();
    // }

    // function testFinalizeBoutsWithInvalidWinner() public {
    //     uint boutId = testBetMultiple();

    //     BettingScenario memory scen = _getScenario_Default();

    //     vm.prank(server.addr);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(InvalidWinnerError.selector, boutId, BoutFighter.Invalid)
    //     );
    //     proxy.finalizeBouts(
    //         boutId,
    //         21,
    //         22,
    //         scen.fighterAPot,
    //         scen.fighterBPot,
    //         BoutFighter.Invalid,
    //         scen.revealValues
    //     );
    // }

    // function testFinalizeBoutsWithPotMismatch() public {
    //     uint boutId = testBetMultiple();

    //     BettingScenario memory scen = _getScenario_Default();

    //     BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);

    //     vm.prank(server.addr);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             PotMismatchError.selector,
    //             boutId,
    //             scen.fighterAPot - 1,
    //             scen.fighterBPot,
    //             bout.totalPot
    //         )
    //     );
    //     proxy.finalizeBouts(
    //         boutId,
    //         21,
    //         22,
    //         scen.fighterAPot - 1,
    //         scen.fighterBPot,
    //         scen.winner,
    //         scen.revealValues
    //     );
    // }

    // function testFinalizeBoutsWithInsufficientRevealValues() public {
    //     uint boutId = testBetMultiple();

    //     BettingScenario memory scen = _getScenario_Default();

    //     uint8[] memory badRevealValues = new uint8[](1);

    //     vm.prank(server.addr);
    //     vm.expectRevert(abi.encodeWithSelector(RevealValuesError.selector, boutId));
    //     proxy.finalizeBouts(
    //         boutId,
    //         21,
    //         22,
    //         scen.fighterAPot,
    //         scen.fighterBPot,
    //         scen.winner,
    //         badRevealValues
    //     );
    // }

    // function testFinalizeBouts() public returns (uint boutId) {
    //     boutId = testBetMultiple();

    //     BettingScenario memory scen = _getScenario_Default();

    //     uint preEndedBouts = proxy.getEndedBouts();

    //     vm.prank(server.addr);
    //     proxy.finalizeBouts(
    //         boutId,
    //         21,
    //         22,
    //         scen.fighterAPot,
    //         scen.fighterBPot,
    //         scen.winner,
    //         scen.revealValues
    //     );

    //     // check the state
    //     BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
    //     assertEq(bout.state, BoutState.Ended, "state");
    //     assertGt(bout.endTime, 0, "end time");
    //     assertEq(bout.winner, scen.winner, "winner");
    //     assertEq(bout.loser, scen.loser, "loser");

    //     assertEq(bout.revealValues, scen.revealValues, "reveal values");

    //     assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterA), 21, "fighter A id");
    //     assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterB), 22, "fighter B id");
    //     assertEq(
    //         proxy.getBoutFighterPot(boutId, BoutFighter.FighterA),
    //         scen.fighterAPot,
    //         "fighter A pot"
    //     );
    //     assertEq(
    //         proxy.getBoutFighterPot(boutId, BoutFighter.FighterB),
    //         scen.fighterBPot,
    //         "fighter B pot"
    //     );
    //     assertEq(
    //         proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterA),
    //         scen.fighterAPot,
    //         "fighter A pot balance"
    //     );
    //     assertEq(
    //         proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterB),
    //         scen.fighterBPot,
    //         "fighter B pot balance"
    //     );

    //     // check global state
    //     assertEq(proxy.getEndedBouts(), preEndedBouts + 1, "ended bouts");
    // }

    // function testFinalizeBoutsCreatesBoutIfNeeded() public {
    //     uint boutId = 100; // doesn't exist

    //     BettingScenario memory scen = _getScenario_Default();

    //     uint preEndedBouts = proxy.getEndedBouts();

    //     uint8[] memory emptyRevealValues;

    //     vm.prank(server.addr);
    //     proxy.finalizeBouts(boutId, 21, 22, 0, 0, scen.winner, emptyRevealValues);

    //     // check total bouts
    //     assertEq(proxy.getTotalBouts(), 1, "total bouts");
    //     assertEq(proxy.getBoutIdByIndex(1), boutId, "bout id by index");

    //     // check bout state
    //     BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
    //     assertEq(bout.state, BoutState.Ended, "state");
    //     assertGt(bout.endTime, 0, "end time");
    //     assertEq(bout.totalPot, 0, "total pot");
    //     assertEq(bout.revealValues, emptyRevealValues, "reveal values");
    //     assertEq(bout.winner, scen.winner, "winner");
    //     assertEq(bout.loser, scen.loser, "loser");

    //     assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterA), 21, "fighter A id");
    //     assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterB), 22, "fighter B id");
    //     assertEq(proxy.getBoutFighterPot(boutId, BoutFighter.FighterA), 0, "fighter A pot");
    //     assertEq(proxy.getBoutFighterPot(boutId, BoutFighter.FighterB), 0, "fighter B pot");
    //     assertEq(
    //         proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterA),
    //         0,
    //         "fighter A pot balance"
    //     );
    //     assertEq(
    //         proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterB),
    //         0,
    //         "fighter B pot balance"
    //     );

    //     // check global state
    //     assertEq(proxy.getEndedBouts(), preEndedBouts + 1, "ended bouts");
    // }

    // function testFinalizeBoutsEmitsEvent() public {
    //     uint boutId = testBetMultiple();

    //     BettingScenario memory scen = _getScenario_Default();

    //     vm.recordLogs();

    //     vm.prank(server.addr);
    //     proxy.finalizeBouts(
    //         boutId,
    //         21,
    //         22,
    //         scen.fighterAPot,
    //         scen.fighterBPot,
    //         scen.winner,
    //         scen.revealValues
    //     );

    //     // check logs
    //     Vm.Log[] memory entries = vm.getRecordedLogs();
    //     assertEq(entries[0].topics.length, 1, "Invalid event count");
    //     assertEq(entries[0].topics[0], keccak256("BoutEnded(uint256)"));
    //     uint eBoutId = abi.decode(entries[0].data, (uint));
    //     assertEq(eBoutId, boutId, "boutId incorrect");
    // }

    // function testFinalizeBoutsRevealsBetsCorrectly() public returns (uint boutId) {
    //     boutId = 100;

    //     BettingScenario memory scen = _getScenario_Default();

    //     // place bets
    //     uint totalBetAmount = 0;
    //     for (uint i = 0; i < scen.players.length; i += 1) {
    //         Wallet memory player = scen.players[i];
    //         totalBetAmount += scen.betAmounts[i];
    //         _bet(player.addr, boutId, scen.betValues[i], scen.betAmounts[i]);
    //     }

    //     vm.prank(server.addr);
    //     proxy.finalizeBouts(
    //         boutId,
    //         21,
    //         22,
    //         scen.fighterAPot,
    //         scen.fighterBPot,
    //         scen.winner,
    //         scen.revealValues
    //     );

    //     uint8[] memory revealValues = proxy.getBoutNonMappingInfo(boutId).revealValues;

    //     // check the state
    //     assertEq(revealValues, scen.revealValues, "reveal values");

    //     // check revealed bets
    //     for (uint i = 0; i < scen.players.length; i++) {
    //         Wallet memory player = scen.players[i];

    //         BoutFighter revealedBet = proxy.getBoutRevealedBet(boutId, player.addr);

    //         assertEq(revealedBet, scen.betTargets[i], "revealed target");
    //     }
    // }

    // function testFinalizeBoutsAndRevealedBetForNonBettor() public {
    //     uint boutId = testBetMultiple();

    //     BettingScenario memory scen = _getScenario_Default();

    //     vm.prank(server.addr);
    //     proxy.finalizeBouts(
    //         boutId,
    //         21,
    //         22,
    //         scen.fighterAPot,
    //         scen.fighterBPot,
    //         scen.winner,
    //         scen.revealValues
    //     );

    //     BoutFighter revealedBet = proxy.getBoutRevealedBet(boutId, vm.addr(666));
    //     assertEq(revealedBet, BoutFighter.Invalid, "no target");
    // }

    // ------------------------------------------------------ //
    //
    // Private/internal methods
    //
    // ------------------------------------------------------ //

    struct BettingScenario {
        uint fighterAId;
        uint fighterBId;
        uint fighterANumBettors;
        uint fighterBNumBettors;
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
            abi.encode(
                uint32(boutId),
                uint16(scen.fighterAId),
                uint16(scen.fighterBId),
                uint16(scen.fighterANumBettors),
                uint16(scen.fighterBNumBettors),
                scen.fighterAPot,
                scen.fighterBPot,
                uint8(scen.winner)
            );
    }

    // 5 playres, 2 bet on winner, 3 on loser
    function _getScenario_Default() internal returns (BettingScenario memory scen) {
        scen = _buildScenarioDefaults(scen);
        scen.winner = BoutFighter.FighterB;
        scen.loser = BoutFighter.FighterA;
        scen.fighterANumBettors = 3;
        scen.fighterBNumBettors = 2;
        scen.fighterAPot = 100;
        scen.fighterBPot = 200;
    }

    // 5 players, all bet on the loser
    function _getScenario_AllOnLoser() internal returns (BettingScenario memory scen) {
        scen = _buildScenarioDefaults(scen);
        scen.winner = BoutFighter.FighterB;
        scen.loser = BoutFighter.FighterA;
        scen.fighterANumBettors = 5;
        scen.fighterBNumBettors = 0;
        scen.fighterAPot = 100;
        scen.fighterBPot = 0;
    }

    // 5 players, all bet on the winner
    function _getScenario_AllOnWinner() internal returns (BettingScenario memory scen) {
        scen = _buildScenarioDefaults(scen);
        scen.winner = BoutFighter.FighterB;
        scen.loser = BoutFighter.FighterA;
        scen.fighterANumBettors = 0;
        scen.fighterBNumBettors = 5;
        scen.fighterAPot = 0;
        scen.fighterBPot = 200;
    }

    function _buildScenarioDefaults(
        BettingScenario memory scen
    ) internal returns (BettingScenario memory) {
        scen.fighterAId = 21;
        scen.fighterBId = 22;
    }
}
