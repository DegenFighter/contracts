// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { SafeMath } from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

import { AppStorage, LibAppStorage, Bout, BoutState, BoutFighter } from "../Objects.sol";
import { LibToken, LibTokenIds } from "src/libs/LibToken.sol";
import { LibConstants } from "../libs/LibConstants.sol";
import { LibEip712 } from "../libs/LibEip712.sol";
import "../Errors.sol";

library LibBetting {
    using SafeMath for uint;

    function getBout(uint boutId) internal view returns (Bout storage bout) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        bout = s.bouts[s.boutIdByIndex[boutId]];
    }

    function getBoutOrCreate(uint boutId) internal returns (Bout storage bout) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        bout = s.bouts[boutId];

        if (uint(bout.state) == uint(BoutState.Uninitialized)) {
            s.totalBouts++;
            s.boutIdByIndex[s.totalBouts] = boutId;
            bout.state = BoutState.Created;
        }
    }

    function bet(uint boutId, address wallet, uint8 br, uint amount, uint deadline, uint8 sigV, bytes32 sigR, bytes32 sigS) external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = getBoutOrCreate(boutId);

        if (bout.state != BoutState.Created) {
            revert BoutInWrongStateError(boutId, bout.state);
        }

        address server = s.addresses[LibConstants.SERVER_ADDRESS];
        address bettor = wallet;

        // recover signer
        bytes32 digest = calculateBetSignature(server, bettor, boutId, br, amount, deadline);
        address signer = LibEip712.recover(digest, sigV, sigR, sigS);

        // final checks
        if (signer != server) {
            revert SignerMustBeServerError();
        }
        if (block.timestamp >= deadline) {
            revert SignatureExpiredError();
        }
        if (amount < LibConstants.MIN_BET_AMOUNT) {
            revert MinimumBetAmountError(boutId, bettor, amount);
        }
        if (br < 1 || br > 3) {
            revert InvalidBetTargetError(boutId, bettor, br);
        }

        // replace old bet?
        if (bout.hiddenBets[bettor] != 0) {
            // refund old bet
            bout.totalPot = bout.totalPot.sub(bout.betAmounts[bettor]);
            LibToken.transfer(LibTokenIds.TOKEN_MEME, address(this), bettor, bout.betAmounts[bettor]);
        }
        // new bet?
        else {
            // add to bettor list
            bout.numSupporters += 1;
            bout.bettors[bout.numSupporters] = bettor;
            bout.bettorIndexes[bettor] = bout.numSupporters;
            // update user data
            s.userTotalBoutsBetOn[bettor] += 1;
            s.userBoutsBetOnByIndex[bettor][s.userTotalBoutsBetOn[bettor]] = boutId;
        }

        // add to pot
        bout.totalPot = bout.totalPot.add(amount);
        bout.betAmounts[bettor] = amount;
        bout.hiddenBets[bettor] = br;

        // transfer bet
        claimWinnings(bettor, 1);
        LibToken.transfer(LibTokenIds.TOKEN_MEME, bettor, address(this), amount);
    }

    function endBout(uint boutId, uint fighterAId, uint fighterBId, uint fighterAPot, uint fighterBPot, BoutFighter winner, uint8[] calldata revealValues) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = getBoutOrCreate(boutId);

        if (bout.state != BoutState.Created) {
            revert BoutInWrongStateError(boutId, bout.state);
        }

        if (winner != BoutFighter.FighterA && winner != BoutFighter.FighterB) {
            revert InvalidWinnerError(boutId, winner);
        }

        if (fighterAPot.add(fighterBPot) != bout.totalPot) {
            revert PotMismatchError(boutId, fighterAPot, fighterBPot, bout.totalPot);
        }

        bout.state = BoutState.Ended;

        bout.revealValues = revealValues;

        bout.fighterIds[BoutFighter.FighterA] = fighterAId;
        bout.fighterPots[BoutFighter.FighterA] = fighterAPot;
        bout.fighterPotBalances[BoutFighter.FighterA] = fighterAPot;

        bout.fighterIds[BoutFighter.FighterB] = fighterBId;
        bout.fighterPots[BoutFighter.FighterB] = fighterBPot;
        bout.fighterPotBalances[BoutFighter.FighterB] = fighterBPot;

        bout.winner = winner;
        bout.loser = (winner == BoutFighter.FighterA ? BoutFighter.FighterB : BoutFighter.FighterA);

        bout.endTime = block.timestamp;

        s.endedBouts++;
    }

    function claimWinnings(address wallet, uint maxBoutsToClaim) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint totalWinnings = 0;
        uint count = 0;
        uint totalBoutsBetOn = s.userTotalBoutsBetOn[wallet];

        for (uint i = s.userTotalBoutsWinningsClaimed[wallet] + 1; i <= totalBoutsBetOn && count < maxBoutsToClaim; i++) {
            uint boutId = s.userBoutsBetOnByIndex[wallet][i];

            (uint total, uint selfAmount, uint won) = getBoutWinnings(boutId, wallet);

            Bout storage bout = s.bouts[boutId];

            bout.winningsClaimed[wallet] = true;

            if (total > 0) {
                bout.fighterPotBalances[bout.winner] = bout.fighterPotBalances[bout.winner].sub(selfAmount);
                bout.fighterPotBalances[bout.loser] = bout.fighterPotBalances[bout.loser].sub(won);
                totalWinnings = totalWinnings.add(total);
            }

            s.userTotalBoutsWinningsClaimed[wallet]++;
            count++;
        }

        // transfer winnings
        if (totalWinnings > 0) {
            LibToken.transfer(LibTokenIds.TOKEN_MEME, address(this), wallet, totalWinnings);
        }
    }

    function getClaimableWinnings(address wallet) internal view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint winnings = 0;
        uint totalBoutsBetOn = s.userTotalBoutsBetOn[wallet];

        for (uint i = s.userTotalBoutsWinningsClaimed[wallet] + 1; i <= totalBoutsBetOn; i++) {
            uint boutId = s.userBoutsBetOnByIndex[wallet][i];
            (uint total, , ) = getBoutWinnings(boutId, wallet);
            winnings = winnings.add(total);
        }

        return winnings;
    }

    function getBoutWinnings(uint boutId, address wallet) internal view returns (uint total, uint selfAmount, uint won) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = s.bouts[boutId];

        // calculate which way player bet
        BoutFighter bet = getRevealedBet(bout, wallet);

        // bet on winner?
        if (bet == bout.winner) {
            // how much of losing pot do we get?
            uint ratio = (bout.betAmounts[wallet] * 1000 ether) / bout.fighterPots[bout.winner];
            won = (ratio * bout.fighterPots[bout.loser]) / 1000 ether;
            // how much did we put in?
            selfAmount = bout.betAmounts[wallet];
            // total winnings
            total = selfAmount + won;
        }
    }

    function getRevealedBet(Bout storage bout, address wallet) internal view returns (BoutFighter bet) {
        uint index = bout.bettorIndexes[wallet] - 1;
        uint rPackedIndex = index >> 4;
        uint8 r = (bout.revealValues[rPackedIndex] >> ((3 - (index % 4)) * 2)) & 3;
        uint8 rawBet;
        if (bout.hiddenBets[wallet] >= r) {
            rawBet = bout.hiddenBets[wallet] - r;
            // default to 0 if invalid
            if (rawBet != 0 && rawBet != 1) {
                rawBet = 0;
            }
        }
        bet = BoutFighter(rawBet + 1);
    }

    function calculateBetSignature(address server, address wallet, uint boutId, uint8 br, uint amount, uint deadline) internal returns (bytes32) {
        return
            LibEip712.hashTypedDataV4(
                keccak256(abi.encode(keccak256("calculateBetSignature(address,address,uint256,uint8,uint256,uint256)"), server, wallet, boutId, br, amount, deadline))
            );
    }
}
