// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { Bout } from "../Objects.sol";

interface IInfoFacet {
    function getTotalBouts() external view returns (uint);

    function getBoutIdByIndex(uint boutIndex) external view returns (uint);

    function getTotalFinalizedBouts() external view returns (uint);

    function getBout(uint boutId) external view returns (Bout memory);

    function getUserTotalBetsMade(address user) external view returns (uint);

    function getUserTotalBetsWon(address user) external view returns (uint);

    function getUserTotalAmountBet(address user) external view returns (uint);

    function getUserTotalAmountWon(address user) external view returns (uint);
}
