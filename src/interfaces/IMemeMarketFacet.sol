// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { MemeBuySizeDollars } from "../Objects.sol";

interface IMemeMarketFacet {
    function claimFreeMeme() external;

    function getMemeCost(
        MemeBuySizeDollars size
    ) external view returns (uint256 cost, uint256 buyAmount);

    function buyMeme(MemeBuySizeDollars size) external payable;
}
