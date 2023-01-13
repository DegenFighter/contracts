// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { MemeBuySize } from "../Objects.sol";

interface IMemeMarketFacet {
    function buyMeme(MemeBuySize size) external;
}
