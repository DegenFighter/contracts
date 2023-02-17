// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { FacetBase } from "../FacetBase.sol";
import { AppStorage, LibAppStorage, Bout } from "../Objects.sol";
import { IInfoFacet } from "../interfaces/IInfoFacet.sol";
import { LibBetting } from "../libs/LibBetting.sol";

contract InfoFacet is FacetBase, IInfoFacet {
    constructor() FacetBase() {}

    function getTotalBouts() external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.totalBouts;
    }

    function getBoutIdByIndex(uint boutIndex) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.boutIdByIndex[boutIndex];
    }

    function getTotalFinalizedBouts() external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.finalizedBouts;
    }

    function getBout(uint boutId) external view returns (Bout memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.bouts[boutId];
    }

    function getUserTotalBetsMade(address user) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.userTotalBetsMade[user];
    }

    function getUserTotalBetsWon(address user) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.userTotalBetsWon[user];
    }

    function getUserTotalAmountBet(address user) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.userTotalAmountBet[user];
    }

    function getUserTotalAmountWon(address user) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.userTotalAmountWon[user];
    }
}
