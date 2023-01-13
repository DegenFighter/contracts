// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { Bout, BoutFighter } from "../Objects.sol";

interface IBettingFacet {
    event BoutCreated(uint boutNum);
    event BetPlaced(uint boutNum, address supporter);
    event BetsRevealed(uint boutNum, uint numBetsRevealed);
    event BoutEnded(uint boutNum);

    function createBout(uint fighterA, uint fighterB) external;

    function calculateBetSignature(address server, address supporter, uint boutNum, uint8 br, uint amount, uint deadline) external returns (bytes32);

    function bet(uint boutNum, uint8 br, uint amount, uint deadline, uint8 sigV, bytes32 sigR, bytes32 sigS) external;

    function revealBets(uint boutNum, uint numValues, uint8[] calldata rPacked) external;

    function endBout(uint boutNum, BoutFighter winner) external;

    function getBoutWinnings(uint boutNum, address wallet) external view returns (uint total, uint selfAmount, uint won);

    function getClaimableWinnings(address wallet) external view returns (uint);

    function claimWinnings(address wallet, uint maxBoutsToClaim) external;
}
