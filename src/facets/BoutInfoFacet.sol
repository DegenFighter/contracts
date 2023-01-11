// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { AppStorage, LibAppStorage, Bout, BoutParticipant, BoutNonMappingInfo } from "../Base.sol";
import { IBoutInfoFacet } from "../interfaces/IBoutInfoFacet.sol";

contract BoutInfoFacet is IBoutInfoFacet {
    function getTotalBouts() external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.totalBouts;
    }

    function getBoutNonMappingInfo(uint boutNum) external view returns (BoutNonMappingInfo memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutNum];

        return BoutNonMappingInfo(boutNum, bout.state, bout.numSupporters, bout.numRevealedBets, bout.totalPot, bout.revealTime, bout.endTime, bout.winner, bout.loser);
    }

    function getBoutSupporter(uint boutNum, uint supporterNum) external view returns (address) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutNum];
        return bout.supporters[supporterNum];
    }

    function getBoutHiddenBet(uint boutNum, address supporter) external view returns (uint8) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutNum];
        return bout.hiddenBets[supporter];
    }

    function getBoutRevealedBet(uint boutNum, address supporter) external view returns (BoutParticipant) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutNum];
        return bout.revealedBets[supporter];
    }

    function getBoutBetAmount(uint boutNum, address supporter) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutNum];
        return bout.betAmounts[supporter];
    }

    function getBoutFighterId(uint boutNum, BoutParticipant p) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutNum];
        return bout.fighterIds[p];
    }

    function getBoutFighterPot(uint boutNum, BoutParticipant p) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutNum];
        return bout.fighterPots[p];
    }

    function getBoutFighterPotBalance(uint boutNum, BoutParticipant p) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutNum];
        return bout.fighterPotBalances[p];
    }
}
