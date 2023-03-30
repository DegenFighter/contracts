// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { BoutNonMappingInfo, BoutFighter } from "../Objects.sol";

interface IInfoFacet {
    function getTotalBouts() external view returns (uint);

    function getBoutIdByIndex(uint boutIndex) external view returns (uint);

    function getUserBoutsWinningsClaimed(address wallet) external view returns (uint);

    function getUserBoutsBetOn(address wallet) external view returns (uint);

    function getUserBoutBetOnAtIndex(address wallet, uint index) external view returns (uint);

    function getBoutNonMappingInfo(uint boutId) external view returns (BoutNonMappingInfo memory);

    function getBoutBettors(
        uint boutId,
        uint startIndex,
        uint endIndex
    ) external view returns (address[] memory);

    function getBetByIndex(
        uint boutId,
        uint bettorNum
    ) external view returns (address, uint, uint8, BoutFighter);

    function getBetByBettor(
        uint boutId,
        address bettor
    ) external view returns (uint, uint, uint8, BoutFighter);

    function getBoutWinningsClaimed(uint boutId, address bettor) external view returns (bool);

    function getBoutFighterId(uint boutId, BoutFighter p) external view returns (uint);

    function getBoutFighterPotBalance(uint boutId, BoutFighter p) external view returns (uint);
}
