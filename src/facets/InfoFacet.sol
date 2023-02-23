// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { FacetBase } from "../FacetBase.sol";
import { AppStorage, LibAppStorage, Bout, BoutFighter, BoutNonMappingInfo } from "../Objects.sol";
import { IInfoFacet } from "../interfaces/IInfoFacet.sol";
import { LibBetting } from "../libs/LibBetting.sol";

contract InfoFacet is FacetBase, IInfoFacet {
    function getTotalBouts() external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.totalBouts;
    }

    function getBoutIdByIndex(uint boutIndex) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.boutIdByIndex[boutIndex];
    }

    function getUserBoutsWinningsClaimed(address wallet) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.userTotalBoutsBetOn[wallet] - s.userBoutsWinningsToClaimList[wallet].len;
    }

    function getUserBoutsBetOn(address wallet) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.userTotalBoutsBetOn[wallet];
    }

    function getUserBoutBetOnAtIndex(address wallet, uint index) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.userBoutsBetOnByIndex[wallet][index];
    }

    function getBoutNonMappingInfo(uint boutId) external view returns (BoutNonMappingInfo memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutId];
        return
            BoutNonMappingInfo({
                numBettors: bout.numBettors,
                totalPot: bout.totalPot,
                expiryTime: bout.expiryTime,
                endTime: bout.endTime,
                state: bout.state,
                winner: bout.winner,
                revealValues: bout.revealValues
            });
    }

    function getBoutSupporter(uint boutId, uint bettorNum) external view returns (address) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutId];
        return bout.bettors[bettorNum];
    }

    function getBoutHiddenBet(uint boutId, address bettor) external view returns (uint8) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutId];
        return bout.hiddenBets[bettor];
    }

    function getBoutRevealedBet(uint boutId, address bettor) external view returns (BoutFighter) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutId];
        return LibBetting.getRevealedBet(bout, bettor);
    }

    function getBoutBetAmount(uint boutId, address bettor) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutId];
        return bout.betAmounts[bettor];
    }

    function getBoutWinningsClaimed(uint boutId, address bettor) external view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutId];
        return bout.winningsClaimed[bettor];
    }

    function getBoutFighterId(uint boutId, BoutFighter p) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutId];
        return bout.fighterIds[p];
    }

    function getBoutFighterPotBalance(uint boutId, BoutFighter p) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutId];
        return bout.fighterPotBalances[p];
    }
}
