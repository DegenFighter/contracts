// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { BoutTarget } from "../Base.sol";

interface ISupportFacet {
    event BoutCreated(uint256 indexed boutNum);
    event BoutSupportRevealed(uint256 indexed boutNum);
    event BoutEnded(uint256 indexed boutNum);

    function createBout(uint fighterA, uint fighterB) external returns (uint boutNum);

    function revealSupport(uint boutNum) external;

    function endBout(uint boutNum, BoutTarget winner) external;

    function getClaimableWinnings(address wallet) external view returns (uint);

    function claimWinnings(address wallet) external;
}
