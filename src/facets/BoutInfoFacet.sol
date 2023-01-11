// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { FacetBase } from "../FacetBase.sol";
import { AppStorage, LibAppStorage, Bout, BoutFighter, BoutNonMappingInfo } from "../Objects.sol";
import { IBoutInfoFacet } from "../interfaces/IBoutInfoFacet.sol";

contract BoutInfoFacet is FacetBase, IBoutInfoFacet {
    constructor() FacetBase() {}

    function getTotalBouts() external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.totalBouts;
    }

    function getEndedBouts() external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.endedBouts;
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

    function getBoutRevealedBet(uint boutNum, address supporter) external view returns (BoutFighter) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutNum];
        return bout.revealedBets[supporter];
    }

    function getBoutBetAmount(uint boutNum, address supporter) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutNum];
        return bout.betAmounts[supporter];
    }

    function getBoutFighterId(uint boutNum, BoutFighter p) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutNum];
        return bout.fighterIds[p];
    }

    function getBoutFighterPot(uint boutNum, BoutFighter p) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutNum];
        return bout.fighterPots[p];
    }

    function getBoutFighterPotBalance(uint boutNum, BoutFighter p) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutNum];
        return bout.fighterPotBalances[p];
    }
}
