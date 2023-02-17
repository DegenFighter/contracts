// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { AppStorage, LibAppStorage } from "../Objects.sol";
import { IBettingFacet } from "../interfaces/IBettingFacet.sol";
import { FacetBase } from "../FacetBase.sol";
import { LibBetting } from "../libs/LibBetting.sol";

contract BettingFacet is FacetBase, IBettingFacet {
    constructor() FacetBase() {}

    function finalizeBouts(uint numBouts, bytes calldata boutData) external isServer {
        uint start = 0;
        uint end = LibBetting.FINALIZE_CHUNK_BYTES_LEN;
        uint[] memory boutIds = new uint[](numBouts);

        for (uint i = 0; i < numBouts; i += 1) {
            boutIds[i] = LibBetting.finalizeBout(boutData[start:end]);
            start = end;
            end += LibBetting.FINALIZE_CHUNK_BYTES_LEN;
        }

        emit BoutsFinalized(numBouts, boutIds);
    }
}
