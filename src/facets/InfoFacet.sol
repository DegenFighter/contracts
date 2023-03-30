// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { FacetBase } from "../FacetBase.sol";
import { AppStorage, LibAppStorage, Bout, BoutFighter, BoutNonMappingInfo, BetInfo } from "../Objects.sol";
import { IInfoFacet } from "../interfaces/IInfoFacet.sol";
import { LibBetting } from "../libs/LibBetting.sol";
import "../Errors.sol";

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

    function getBoutBettors(
        uint boutId,
        uint startIndex,
        uint endIndex
    ) external view returns (address[] memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutId];
        uint numBettors = bout.numBettors;

        if (
            1 > startIndex ||
            startIndex > numBettors ||
            1 > endIndex ||
            endIndex > numBettors ||
            startIndex > endIndex
        ) {
            revert OutOfBoundsError();
        }

        uint numBettorsToReturn = endIndex - startIndex + 1;
        address[] memory bettors = new address[](numBettorsToReturn);
        for (uint i = 0; i < numBettorsToReturn; i++) {
            bettors[i] = bout.bettors[startIndex + i];
        }
        return bettors;
    }

    function getBetByIndex(uint boutId, uint bettorNum) external view returns (BetInfo memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutId];
        address bettor = bout.bettors[bettorNum];
        BetInfo storage betInfo = bout.bets[bettor];
        return
            BetInfo({
                amount: betInfo.amount,
                hidden: betInfo.hidden,
                winningsClaimed: betInfo.winningsClaimed,
                revealed: LibBetting.getRevealedBet(bout, bettor)
            });
    }

    function getBetByBettor(uint boutId, address bettor) external view returns (BetInfo memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutId];
        BetInfo storage betInfo = bout.bets[bettor];
        return
            BetInfo({
                amount: betInfo.amount,
                hidden: betInfo.hidden,
                winningsClaimed: betInfo.winningsClaimed,
                revealed: LibBetting.getRevealedBet(bout, bettor)
            });
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
