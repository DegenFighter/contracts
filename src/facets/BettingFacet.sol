// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { BytesLib } from "solidity-bytes-utils/BytesLib.sol";

import { AppStorage, LibAppStorage } from "../Objects.sol";
import { IBettingFacet } from "../interfaces/IBettingFacet.sol";
import { FacetBase } from "../FacetBase.sol";
import { LibBetting } from "../libs/LibBetting.sol";

contract BettingFacet is FacetBase, IBettingFacet {
    constructor() FacetBase() {}

    function finalizeBouts(uint numBouts, bytes calldata boutData) external isServer {
        uint start = 0;

        for (uint i = 0; i < numBouts; i += 1) {
            uint boutId = LibBetting.finalizeBout(
                BytesLib.slice(boutData, start, LibBetting.FINALIZE_CHUNK_BYTES_LEN)
            );
            emit BoutFinalized(boutId);
            start += LibBetting.FINALIZE_CHUNK_BYTES_LEN;
        }
    }
}
