// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { BoutNonMappingInfo, BoutParticipant } from "../Base.sol";

interface IBoutInfoFacet {
    function getBoutNonMappingInfo(uint boutNum) external view returns (BoutNonMappingInfo memory);

    function getBoutSupporter(uint boutNum, uint supporterNum) external view returns (address);

    function getBoutHiddenBet(uint boutNum, address supporter) external view returns (uint8);

    function getBoutRevealedBet(uint boutNum, address supporter) external view returns (BoutParticipant);

    function getBoutBetAmount(uint boutNum, address supporter) external view returns (uint);

    function getBoutFighterId(uint boutNum, BoutParticipant p) external view returns (uint);

    function getBoutFighterPot(uint boutNum, BoutParticipant p) external view returns (uint);

    function getBoutFighterPotBalance(uint boutNum, BoutParticipant p) external view returns (uint);
}
