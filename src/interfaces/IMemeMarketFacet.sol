// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { MemeBuySizeDollars } from "../Objects.sol";

interface IMemeMarketFacet {
    function claimFreeMeme() external;

    function buyMeme(MemeBuySizeDollars size) external;
}
