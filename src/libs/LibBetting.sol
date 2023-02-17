// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { SafeMath } from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import { BytesLib } from "solidity-bytes-utils/BytesLib.sol";

import { AppStorage, LibAppStorage, Bout, BoutState, BoutFighter, BoutList, BoutListNode } from "../Objects.sol";
import { LibToken, LibTokenIds } from "src/libs/LibToken.sol";
import { LibConstants } from "../libs/LibConstants.sol";
import { LibEip712 } from "../libs/LibEip712.sol";
import { LibLinkedList } from "../libs/LibLinkedList.sol";
import "../Errors.sol";

library LibBetting {
    using SafeMath for uint;

    /**
     * @dev The number of bytes in a bout's data when encodePacked()
     *
     * sanityCheck: uint8            // 1 byte
     * boutId: uint32                // 4 bytes
     * fighterAId: uint16            // 2 bytes
     * fighterBId: uint16            // 2 bytes
     * fighterANumBettors: uint16    // 2 bytes
     * fighterBNumBettors: uint16    // 2 bytes
     * fighterAPot: uint256          // 32 bytes
     * fighterBPot: uint256          // 32 bytes
     * winner: uint8                 // 1 byte
     */
    uint internal constant FINALIZE_CHUNK_BYTES_LEN = 78;

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
            abi.encodePacked(
                uint8(101),
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

    function finalizeBout(bytes memory data) internal returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint sanityCheck = BytesLib.toUint8(data, 0);

        if (sanityCheck != 101) {
            revert InvalidFinalizedBoutDataError(sanityCheck);
        }

        uint boutId = BytesLib.toUint32(data, 1);
        uint fighterAId = BytesLib.toUint16(data, 5);
        uint fighterBId = BytesLib.toUint16(data, 7);
        uint fighterANumBettors = BytesLib.toUint16(data, 9);
        uint fighterBNumBettors = BytesLib.toUint16(data, 11);
        uint fighterAPot = BytesLib.toUint256(data, 13);
        uint fighterBPot = BytesLib.toUint256(data, 45);
        uint8 winnerInt = BytesLib.toUint8(data, 77);

        if (winnerInt != uint8(BoutFighter.FighterA) && winnerInt != uint8(BoutFighter.FighterB)) {
            revert InvalidWinnerError(boutId, winnerInt);
        }

        BoutFighter winner = BoutFighter(winnerInt);
        Bout storage bout = s.bouts[boutId];

        if (bout.state != BoutState.Uninitialized) {
            revert BoutInWrongStateError(boutId, bout.state);
        }

        if (fighterANumBettors > 0 && fighterAPot == 0) {
            revert InvalidBettorDataError(boutId, BoutFighter.FighterA);
        }

        if (fighterBNumBettors > 0 && fighterBPot == 0) {
            revert InvalidBettorDataError(boutId, BoutFighter.FighterB);
        }

        s.totalBouts++;
        s.finalizedBouts++;
        s.boutIdByIndex[s.totalBouts] = boutId;
        bout.state = BoutState.Finalized;

        bout.fighterIds = [fighterAId, fighterBId];
        bout.fighterNumBettors = [fighterANumBettors, fighterBNumBettors];
        bout.fighterPots = [fighterAPot, fighterBPot];

        bout.totalPot = fighterAPot.add(fighterBPot);

        bout.winner = winner;
        bout.loser = (winner == BoutFighter.FighterA ? BoutFighter.FighterB : BoutFighter.FighterA);

        bout.finalizeTime = block.timestamp;

        return boutId;
    }
}
