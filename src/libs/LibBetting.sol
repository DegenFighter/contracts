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

    function getBoutOrCreate(uint boutId) internal returns (Bout storage bout) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        bout = s.bouts[boutId];

        if (uint(bout.state) == uint(BoutState.Uninitialized)) {
            s.totalBouts++;
            s.boutIdByIndex[s.totalBouts] = boutId;
            bout.state = BoutState.Created;
        }
    }

    function bet(uint boutId, address wallet, uint8 br, uint amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = getBoutOrCreate(boutId);

        if (bout.state != BoutState.Created) {
            revert BoutInWrongStateError(boutId, bout.state);
        }

        if (amount < LibConstants.MIN_BET_AMOUNT) {
            revert MinimumBetAmountError(boutId, wallet, amount);
        }
        if (br < 1 || br > 3) {
            revert InvalidBetTargetError(boutId, wallet, br);
        }

        /*
        Resolve any unclaimed MEME.

        We do this before incrementing userTotalBoutsBetOn and userBoutsBetOnByIndex below, otherwise the 
        claimWinnings function will not work correctly. 
        */
        claimWinnings(wallet, 1);

        // replace old bet?
        if (bout.hiddenBets[wallet] != 0) {
            // refund old bet
            bout.totalPot = bout.totalPot.sub(bout.betAmounts[wallet]);
            LibToken.transfer(LibTokenIds.TOKEN_MEME, address(this), wallet, bout.betAmounts[wallet]);
        }
        // new bet?
        else {
            // add to bettor list
            bout.numSupporters += 1;
            bout.bettors[bout.numSupporters] = wallet;
            bout.bettorIndexes[wallet] = bout.numSupporters;
            // update user data
            s.userTotalBoutsBetOn[wallet] += 1;
            s.userBoutsBetOnByIndex[wallet][s.userTotalBoutsBetOn[wallet]] = boutId;
        }

        // add to pot
        bout.totalPot = bout.totalPot.add(amount);
        bout.betAmounts[wallet] = amount;
        bout.hiddenBets[wallet] = br;

        // transfer bet amount to contract
        LibToken.transfer(LibTokenIds.TOKEN_MEME, wallet, address(this), amount);
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

    /*
    We pass maxBoutsToClaim = 1 because under normal circumstances, the user will only have one
    unclaimed bout winnings to claim. If the user places bets on lots of bouts before the 
    server suddenl goes down for a while then they'll have lots of unclaimed winnings and/or 
    bets that need to be refunded. In this case, the user may need to call this directly 
    multiple times to get through the backlog. We will enable this in the UI.
    */
    function claimWinnings(address wallet, uint maxBoutsToClaim) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint totalWinnings = 0;
        uint count = 0;
        uint totalBoutsBetOn = s.userTotalBoutsBetOn[wallet];

        for (uint i = s.userTotalBoutsWinningsClaimed[wallet] + 1; i <= totalBoutsBetOn && count < maxBoutsToClaim; i++) {
            uint boutId = s.userBoutsBetOnByIndex[wallet][i];

            // if bout not yet ended
            if (s.bouts[boutId].state == BoutState.Created) {
                // TODO: end it if it's expired
                // break out of loop
                break;
            }

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
