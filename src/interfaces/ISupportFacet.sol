// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { BoutParticipant } from "../Base.sol";

interface ISupportFacet {
    event BoutCreated(uint indexed boutNum);
    event BetPlaced(uint indexed boutNum, address indexed supporter);
    event BetsRevealed(uint indexed boutNum);
    event BoutEnded(uint indexed boutNum);

    function createBout(uint fighterA, uint fighterB) external returns (uint boutNum);

    function calculateBetSignature(address server, address supporter, uint boutNum, uint8 br, uint amount, uint deadline) external returns (bytes32);

    function bet(uint boutNum, uint8 br, uint amount, uint deadline, bytes memory signature) external;

    function revealBets(uint boutNum, uint8[] calldata rPacked) external;

    function endBout(uint boutNum, BoutParticipant winner) external;

    function getClaimableWinnings(address wallet) external view returns (uint);

    function claimWinnings(address wallet) external;
}
