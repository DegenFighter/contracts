// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { Bout, BoutFighter } from "../Objects.sol";

interface IBettingFacet {
    event BetPlaced(uint boutId, address bettor);
    event BoutEnded(uint boutId);

    function bet(
        uint boutId,
        uint8 br,
        uint amount,
        uint deadline,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS
    ) external;

    function endBout(
        uint boutId,
        uint fighterAId,
        uint fighterBId,
        uint fighterAPot,
        uint fighterBPot,
        BoutFighter winner,
        uint8[] calldata revealValues
    ) external;

    function getBoutClaimableAmounts(
        uint boutId,
        address wallet
    ) external view returns (uint totalToClaim, uint selfBetAmount, uint loserPotAmountToClaim);

    function getClaimableWinnings(address wallet) external view returns (uint);

    function claimWinnings(address wallet, uint maxBoutsToClaim) external;

    function calculateBetSignatureDigest(
        address server,
        address bettor,
        uint boutId,
        uint8 br,
        uint amount,
        uint deadline
    ) external view returns (bytes32);
}
