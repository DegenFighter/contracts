// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { Bout, BoutFighter } from "../Objects.sol";

interface IBettingFacet {
    event BoutFinalized(uint boutId);

    function finalizeBouts(uint numBouts, bytes calldata boutData) external;
}
