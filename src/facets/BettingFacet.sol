// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { SafeMath } from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

import "../Errors.sol";
import { AppStorage, LibAppStorage, Bout, BoutState, BoutFighter } from "../Objects.sol";
import { IBettingFacet } from "../interfaces/IBettingFacet.sol";
import { FacetBase } from "../FacetBase.sol";
import { LibConstants } from "../libs/LibConstants.sol";
import { LibEip712 } from "../libs/LibEip712.sol";
import { LibToken } from "../libs/LibToken.sol";

contract BettingFacet is FacetBase, IBettingFacet {
    using SafeMath for uint;

    constructor() FacetBase() {}

    function createBout(uint fighterA, uint fighterB) external isServer {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.totalBouts++;
        Bout storage bout = s.bouts[s.totalBouts];
        bout.id = s.totalBouts;
        bout.state = BoutState.Created;
        bout.winner = BoutFighter.Unknown;
        bout.loser = BoutFighter.Unknown;
        bout.fighterIds[BoutFighter.FighterA] = fighterA;
        bout.fighterIds[BoutFighter.FighterB] = fighterB;

        emit BoutCreated(s.totalBouts);
    }

    function calculateBetSignature(address server, address supporter, uint256 boutNum, uint8 br, uint256 amount, uint256 deadline) public returns (bytes32) {
        return
            LibEip712.hashTypedDataV4(
                keccak256(abi.encode(keccak256("calculateBetSignature(address,address,uint256,uint8,uint256,uint256)"), server, supporter, boutNum, br, amount, deadline))
            );
    }

    function bet(uint boutNum, uint8 br, uint amount, uint deadline, uint8 sigV, bytes32 sigR, bytes32 sigS) external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = s.bouts[boutNum];

        if (bout.state != BoutState.Created) {
            revert BoutInWrongStateError();
        }

        address server = s.addresses[LibConstants.SERVER_ADDRESS];
        address supporter = _msgSender();

        // recover signer
        bytes32 digest = calculateBetSignature(server, supporter, boutNum, br, amount, deadline);
        address signer = LibEip712.recover(digest, sigV, sigR, sigS);

        // final checks
        if (signer != server) {
            revert SignerMustBeServerError();
        }
        if (block.timestamp >= deadline) {
            revert SignatureExpiredError();
        }
        if (amount < LibConstants.MIN_BET_AMOUNT) {
            revert MinimumBetAmountError();
        }
        if (br < 1 || br > 3) {
            revert InvalidBetTargetError();
        }

        // replace old bet?
        if (bout.hiddenBets[supporter] != 0) {
            // refund old bet
            bout.totalPot = bout.totalPot.sub(bout.betAmounts[supporter]);
            LibToken.transfer(LibConstants.TOKEN_MEME, address(this), supporter, bout.betAmounts[supporter]);
        }
        // new bet?
        else {
            // add to supporter list
            bout.numSupporters += 1;
            bout.supporters[bout.numSupporters] = supporter;
        }

        // add to pot
        bout.totalPot = bout.totalPot.add(amount);
        bout.betAmounts[supporter] = amount;
        bout.hiddenBets[supporter] = br;

        // transfer bet
        LibToken.transfer(LibConstants.TOKEN_MEME, supporter, address(this), amount);

        emit BetPlaced(boutNum, supporter);
    }

    function revealBets(uint boutNum, uint numValues, uint8[] calldata rPacked) external isServer {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = s.bouts[boutNum];

        if (bout.state != BoutState.Created && bout.state != BoutState.BetsRevealed) {
            revert BoutInWrongStateError();
        }

        if (bout.numRevealedBets == bout.numSupporters) {
            revert BoutAlreadyFullyRevealedError();
        }

        uint count;

        // do reveal
        for (uint i = bout.numRevealedBets; i < bout.numSupporters && count < numValues; i++) {
            uint rPackedIndex = (i - bout.numRevealedBets) >> 2;
            uint8 r = (rPacked[rPackedIndex] >> ((3 - (i % 4)) * 2)) & 3;
            address supporter = bout.supporters[i + 1];
            uint8 rawBet;
            if (bout.hiddenBets[supporter] >= r) {
                rawBet = bout.hiddenBets[supporter] - r;
            }
            // default to 0 if invalid
            if (rawBet != 0 && rawBet != 1) {
                rawBet = 0;
            }

            // update supporter bet data & fighter pot
            bout.revealedBets[supporter] = (rawBet == 0 ? BoutFighter.FighterA : BoutFighter.FighterB);
            BoutFighter fighter = bout.revealedBets[supporter];
            bout.fighterPots[fighter] = bout.fighterPots[fighter].add(bout.betAmounts[supporter]);

            // count
            bout.numRevealedBets++;
            count++;
        }

        bout.state = BoutState.BetsRevealed;
        bout.revealTime = block.timestamp;

        emit BetsRevealed(boutNum, count);
    }

    function endBout(uint boutNum, BoutFighter winner) external isServer {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = s.bouts[boutNum];

        if (bout.state != BoutState.BetsRevealed) {
            revert BoutInWrongStateError();
        }

        if (bout.endTime != 0) {
            revert BoutAlreadyEndedError();
        }

        if (winner != BoutFighter.FighterA && winner != BoutFighter.FighterB) {
            revert InvalidWinnerError();
        }

        bout.state = BoutState.Ended;
        bout.endTime = block.timestamp;
        bout.winner = winner;
        bout.loser = (winner == BoutFighter.FighterA ? BoutFighter.FighterB : BoutFighter.FighterA);
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

        uint totalWinnings = 0;

        for (uint i = s.userBoutsClaimed[wallet] + 1; i <= s.userBoutsSupported[wallet]; i++) {
            uint boutNum = s.userBoutSupportList[wallet][i];

            (uint total, uint selfAmount, uint won) = _calculateBoutWinnings(wallet, boutNum);

            if (total > 0) {
                Bout storage bout = s.bouts[boutNum];
                bout.fighterPotBalances[bout.winner] = bout.fighterPotBalances[bout.winner].sub(selfAmount);
                bout.fighterPotBalances[bout.loser] = bout.fighterPotBalances[bout.loser].sub(won);
                totalWinnings = totalWinnings.add(total);
            }

            s.userBoutsClaimed[wallet]++;
        }

        // transfer winnings
        if (totalWinnings > 0) {
            LibToken.transfer(LibConstants.TOKEN_MEME, address(this), wallet, totalWinnings);
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
