// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { SafeMath } from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

import { AppStorage, LibAppStorage, Bout, BoutState, BoutFighter, BoutList, BoutListNode } from "../Objects.sol";
import { LibToken, LibTokenIds } from "src/libs/LibToken.sol";
import { LibConstants } from "../libs/LibConstants.sol";
import { LibEip712 } from "../libs/LibEip712.sol";
import { LibLinkedList } from "../libs/LibLinkedList.sol";
import "../Errors.sol";

library LibBetting {
    using SafeMath for uint;

    /**
     * @dev The number of bytes in a bout's data.
     *
     * boutId: uint32                // 4 bytes
     * fighterAId: uint16            // 2 bytes
     * fighterBId: uint16            // 2 bytes
     * fighterANumBettors: uint16    // 2 bytes
     * fighterBNumBettors: uint16    // 2 bytes
     * fighterAPot: uint256          // 32 bytes
     * fighterBPot: uint256          // 32 bytes
     * winner: uint8                 // 1 byte
     */
    uint internal constant FINALIZE_CHUNK_BYTES_LEN = 77;

    function buildFinalizedBoutData(
        uint boutId,
        uint fighterAId,
        uint fighterBId,
        uint fighterANumBettors,
        uint fighterBNumBettors,
        uint fighterAPot,
        uint fighterBPot,
        BoutFighter winner
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                uint32(boutId),
                uint16(fighterAId),
                uint16(fighterBId),
                uint16(fighterANumBettors),
                uint16(fighterBNumBettors),
                fighterAPot,
                fighterBPot,
                uint8(winner)
            );
    }

    function finalizeBout(bytes calldata data) internal returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (data.length != FINALIZE_CHUNK_BYTES_LEN) {
            revert InvalidFinalizedBoutDataLengthError(data.length);
        }

        (
            uint boutId,
            uint fighterAId,
            uint fighterBId,
            uint fighterANumBettors,
            uint fighterBNumBettors,
            uint fighterAPot,
            uint fighterBPot,
            uint winnerInt
        ) = abi.decode(data, (uint32, uint16, uint16, uint16, uint16, uint, uint, uint8));

        BoutFighter winner = BoutFighter(winnerInt);
        Bout storage bout = s.bouts[boutId];

        if (bout.state != BoutState.Uninitialized) {
            revert BoutInWrongStateError(boutId, bout.state);
        }

        if (fighterANumBettors > 0 && fighterAPot == 0) {
            revert InvalidFighterBettorData(boutId, BoutFighter.FighterA);
        }

        if (fighterBNumBettors > 0 && fighterBPot == 0) {
            revert InvalidFighterBettorData(boutId, BoutFighter.FighterB);
        }

        if (winner != BoutFighter.FighterA && winner != BoutFighter.FighterB) {
            revert InvalidWinnerError(boutId, winner);
        }

        s.totalBouts++;
        s.finalizedBouts++;
        s.boutIdByIndex[s.totalBouts] = boutId;
        bout.state = BoutState.Finalized;

        bout.fighterNumBettors = [fighterANumBettors, fighterBNumBettors];
        bout.fighterIds = [fighterAId, fighterBId];
        bout.fighterPots = [fighterAPot, fighterBPot];

        bout.totalPot = fighterAPot.add(fighterBPot);

        bout.winner = winner;
        bout.loser = (winner == BoutFighter.FighterA ? BoutFighter.FighterB : BoutFighter.FighterA);

        bout.finalizeTime = block.timestamp;

        return boutId;
    }
}
