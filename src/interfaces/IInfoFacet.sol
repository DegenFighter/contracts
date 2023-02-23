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

    function getBoutSupporter(uint boutId, uint bettorNum) external view returns (address);

    function getBoutHiddenBet(uint boutId, address bettor) external view returns (uint8);

    function getBoutRevealedBet(uint boutId, address bettor) external view returns (BoutFighter);

    function getBoutBetAmount(uint boutId, address bettor) external view returns (uint);

    function getBoutWinningsClaimed(uint boutId, address bettor) external view returns (bool);

    function getBoutFighterId(uint boutId, BoutFighter p) external view returns (uint);

    function getBoutFighterPotBalance(uint boutId, BoutFighter p) external view returns (uint);
}
