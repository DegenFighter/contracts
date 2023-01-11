// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { SafeMath } from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

import "../Errors.sol";
import { AppStorage, LibAppStorage, Bout, BoutState, BoutParticipant } from "../Objects.sol";
import { IBettingFacet } from "../interfaces/IBettingFacet.sol";
import { FacetBase } from "../FacetBase.sol";
import { LibConstants } from "../libs/LibConstants.sol";
import { LibEip712 } from "../libs/LibEip712.sol";

contract BettingFacet is FacetBase, IBettingFacet {
    using SafeMath for uint;

    constructor() FacetBase() {}

    function createBout(uint fighterA, uint fighterB) external isServer {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.totalBouts++;
        Bout storage bout = s.bouts[s.totalBouts];
        bout.id = s.totalBouts;
        bout.state = BoutState.Created;
        bout.winner = BoutParticipant.Unknown;
        bout.loser = BoutParticipant.Unknown;
        bout.fighterIds[BoutParticipant.FighterA] = fighterA;
        bout.fighterIds[BoutParticipant.FighterB] = fighterB;

        emit BoutCreated(s.totalBouts);
    }

    function calculateBetSignature(address server, address supporter, uint256 boutNum, uint8 br, uint256 amount, uint256 deadline) public returns (bytes32) {
        return
            LibEip712.hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256("calculateBetSignature(address server,address supporter,uint256 boutNum,uint8 br,uint256 amount,uint256 deadline)"),
                        server,
                        supporter,
                        boutNum,
                        br,
                        amount,
                        deadline
                    )
                )
            );
    }

    function bet(uint boutNum, uint8 br, uint amount, uint deadline, bytes memory signature) external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = s.bouts[boutNum];

        if (bout.state == BoutState.Created) {
            revert BoutInWrongStateError(boutNum, bout.state);
        }

        address server = s.addresses[LibConstants.SERVER_ADDRESS];
        address supporter = _msgSender();

        // recover signer
        bytes32 digest = calculateBetSignature(server, supporter, boutNum, br, amount, deadline);
        address signer = LibEip712.recover(digest, signature);

        // final checks
        if (signer != server) {
            revert SignerMustBeServerError();
        }
        if (block.timestamp >= deadline) {
            revert SignatureExpiredError();
        }
        if (amount < LibConstants.MIN_BET_AMOUNT) {
            revert MinimumBetAmountError(boutNum, supporter, amount);
        }
        if (br < 1 || br > 3) {
            revert InvalidBetTargetError(boutNum, supporter, br);
        }

        // replace old bet?
        if (bout.hiddenBets[supporter] != 0) {
            bout.totalPot = bout.totalPot.sub(bout.betAmounts[supporter]).add(amount);
        }
        // new bet?
        else {
            bout.totalPot = bout.totalPot.add(amount);
            bout.numSupporters += 1;
            bout.supporters[bout.numSupporters] = supporter;
        }
        bout.betAmounts[supporter] = amount;
        bout.hiddenBets[supporter] = br;

        emit BetPlaced(boutNum, supporter);
    }

    function revealBets(uint boutNum, uint8[] calldata rPacked) external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = s.bouts[boutNum];

        if (bout.state != BoutState.Created && bout.state != BoutState.SupportRevealed) {
            revert BoutInWrongStateError(boutNum, bout.state);
        }

        if (bout.numRevealedBets == bout.numSupporters) {
            revert BoutAlreadyFullyRevealedError(boutNum);
        }

        bout.state = BoutState.SupportRevealed;
        bout.revealTime = block.timestamp;

        // do reveal
        for (uint i = bout.numRevealedBets; i < bout.numSupporters; i++) {
            uint rPackedIndex = (i - bout.numRevealedBets) >> 2;
            if (rPackedIndex >= rPacked.length) {
                break;
            }
            uint8 r = (rPacked[rPackedIndex] >> ((3 - (i % 4)) * 2)) & 3;
            address supporter = bout.supporters[i + 1];
            uint8 rawBet = bout.hiddenBets[supporter] - r;
            // default to 0 if invalid
            if (rawBet != 0 && rawBet != 1) {
                rawBet = 0;
            }
            bout.revealedBets[supporter] = (rawBet == 0 ? BoutParticipant.FighterA : BoutParticipant.FighterB);
            bout.numRevealedBets++;
        }

        emit BetsRevealed(boutNum, bout.numRevealedBets);
    }

    function endBout(uint boutNum, BoutParticipant winner) external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = s.bouts[boutNum];

        if (bout.state != BoutState.SupportRevealed) {
            revert BoutInWrongStateError(boutNum, bout.state);
        }

        if (bout.endTime != 0) {
            revert BoutAlreadyEndedError(boutNum);
        }

        if (winner != BoutParticipant.FighterA && winner != BoutParticipant.FighterB) {
            revert InvalidWinnerError(boutNum, winner);
        }

        bout.state = BoutState.Ended;
        bout.endTime = block.timestamp;
        bout.winner = winner;
        bout.loser = (winner == BoutParticipant.FighterA ? BoutParticipant.FighterB : BoutParticipant.FighterA);
        s.boutsFinished++;

        emit BoutEnded(boutNum);
    }

    function getClaimableWinnings(address wallet) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint winnings = 0;

        for (uint i = s.userBoutsClaimed[wallet] + 1; i <= s.userBoutsSupported[wallet]; i++) {
            uint boutNum = s.userBoutSupportList[wallet][i];
            (uint total, , ) = _calculateBoutWinnings(wallet, boutNum);
            winnings = winnings.add(total);
        }

        return winnings;
    }

    function claimWinnings(address wallet) external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        for (uint i = s.userBoutsClaimed[wallet] + 1; i <= s.userBoutsSupported[wallet]; i++) {
            uint boutNum = s.userBoutSupportList[wallet][i];

            (uint total, uint selfAmount, uint won) = _calculateBoutWinnings(wallet, boutNum);

            if (total > 0) {
                Bout storage bout = s.bouts[boutNum];
                bout.fighterPotBalances[bout.winner] = bout.fighterPotBalances[bout.winner].sub(selfAmount);
                bout.fighterPotBalances[bout.loser] = bout.fighterPotBalances[bout.loser].sub(won);
                s.memeBalance[address(this)] = s.memeBalance[address(this)].sub(total);
                s.memeBalance[wallet] = s.memeBalance[wallet].add(total);
            }

            s.userBoutsClaimed[wallet]++;
        }
    }

    // Internal methods

    function _calculateBoutWinnings(address wallet, uint boutNum) private view returns (uint total, uint selfAmount, uint won) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = s.bouts[boutNum];

        if (bout.winner == bout.revealedBets[wallet]) {
            // how much of losing pot do we get?
            uint ratio = (bout.betAmounts[wallet] * 1000 ether) / bout.fighterPots[bout.winner];
            won = (ratio * bout.fighterPots[bout.loser]) / 1000 ether;
            // how much did we put in?
            selfAmount = bout.betAmounts[wallet];
            // total winnings
            total = selfAmount + won;
        }
    }
}
