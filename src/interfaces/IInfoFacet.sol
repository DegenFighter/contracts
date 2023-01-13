// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { BoutNonMappingInfo, BoutFighter } from "../Objects.sol";

interface IInfoFacet {
    function getTotalBouts() external view returns (uint);

    function getEndedBouts() external view returns (uint);

    function getUserBoutsWinningsClaimed(address wallet) external view returns (uint);

    function getUserBoutsSupported(address wallet) external view returns (uint);

    function getUserSupportedBoutAtIndex(address wallet, uint index) external view returns (uint);

    function getBoutNonMappingInfo(uint boutNum) external view returns (BoutNonMappingInfo memory);

    function getBoutSupporter(uint boutNum, uint supporterNum) external view returns (address);

    function getBoutHiddenBet(uint boutNum, address supporter) external view returns (uint8);

    function getBoutRevealedBet(uint boutNum, address supporter) external view returns (BoutFighter);

    function getBoutBetAmount(uint boutNum, address supporter) external view returns (uint);

    function getBoutWinningsClaimed(uint boutNum, address supporter) external view returns (bool);

    function getBoutFighterId(uint boutNum, BoutFighter p) external view returns (uint);

    function getBoutFighterPot(uint boutNum, BoutFighter p) external view returns (uint);

    function getBoutFighterPotBalance(uint boutNum, BoutFighter p) external view returns (uint);
}
