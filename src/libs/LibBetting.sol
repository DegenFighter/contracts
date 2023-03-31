// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { SafeMath } from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

import { AppStorage, LibAppStorage, Bout, BoutState, BoutFighter, BoutList, BoutListNode, BetInfo } from "../Objects.sol";
import { LibToken, LibTokenIds } from "./LibToken.sol";
import { LibConstants } from "./LibConstants.sol";
import { LibEip712 } from "./LibEip712.sol";
import { LibLinkedList } from "./LibLinkedList.sol";
import "../Errors.sol";

library LibBetting {
    using SafeMath for uint;

    struct CreateBoutParams {
        // whether to set expiry time - if we're finalizing a bout without betting, we don't want to set the expiry time
        bool setExpiryTime;
        // to decrease gas cost of endBout() calls we can pre-set the variables that would be set in that function
        bool setDefaultValuesToSaveEndBoutGas;
    }

    function getBoutOrCreate(
        uint boutId,
        CreateBoutParams memory params
    ) internal returns (Bout storage bout) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        bout = s.bouts[boutId];

        if (uint(bout.state) == uint(BoutState.Uninitialized)) {
            s.totalBouts++;
            s.boutIdByIndex[s.totalBouts] = boutId;

            bout.state = BoutState.Created;

            if (params.setExpiryTime) {
                bout.expiryTime = block.timestamp + LibConstants.DEFAULT_BOUT_EXPIRATION_TIME;
            }

            if (params.setDefaultValuesToSaveEndBoutGas) {
                bout.revealValues = [0];
                bout.fighterIds[BoutFighter.FighterA] = 1;
                bout.fighterIds[BoutFighter.FighterB] = 1;
                bout.fighterPotBalances[BoutFighter.FighterA] = 1;
                bout.fighterPotBalances[BoutFighter.FighterB] = 1;
                bout.endTime = 1;
                bout.winningsRatio = 1;
                bout.winner = BoutFighter.FighterA;
            }
        }
    }

    function bet(uint boutId, address wallet, uint8 br, uint amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = getBoutOrCreate(
            boutId,
            CreateBoutParams({ setExpiryTime: true, setDefaultValuesToSaveEndBoutGas: true })
        );

        if (bout.state != BoutState.Created) {
            revert BoutInWrongStateError(boutId, bout.state);
        }

        if (amount < LibConstants.MIN_BET_AMOUNT) {
            revert MinimumBetAmountError(boutId, wallet, amount);
        }

        if (br < 1 || br > 3) {
            revert InvalidBetTargetError(boutId, wallet, br);
        }

        // replace old bet?
        if (bout.bets[wallet].amount > 0) {
            // refund old bet
            bout.totalPot = bout.totalPot.sub(bout.bets[wallet].amount);
            LibToken.transfer(
                LibTokenIds.TOKEN_MEME,
                address(this),
                wallet,
                bout.bets[wallet].amount
            );
        }
        // new bet?
        else {
            // add to bettor list
            bout.numBettors += 1;
            bout.bettors[bout.numBettors] = wallet;
            bout.bettorIndexes[wallet] = bout.numBettors;
            // update user data
            s.userTotalBoutsBetOn[wallet] += 1;
            s.userBoutsBetOnByIndex[wallet][s.userTotalBoutsBetOn[wallet]] = boutId;
            LibLinkedList.addToBoutList(s.userBoutsWinningsToClaimList[wallet], boutId);
        }

        // add to pot
        bout.totalPot = bout.totalPot.add(amount);
        // update bet data
        bout.bets[wallet].hidden = br;
        bout.bets[wallet].amount = amount;

        // if not enough MEME for minimum bet then mint them some
        if (amount == LibConstants.MIN_BET_AMOUNT) {
            uint bal = LibToken.balanceOf(LibTokenIds.TOKEN_MEME, wallet);
            if (bal < amount) {
                LibToken.mint(LibTokenIds.TOKEN_MEME, wallet, LibConstants.MIN_BET_AMOUNT - bal);
            }
        }

        // transfer bet amount to contract
        LibToken.transfer(LibTokenIds.TOKEN_MEME, wallet, address(this), amount);
    }

    function endBout(
        uint boutId,
        uint fighterAId,
        uint fighterBId,
        uint fighterAPot,
        uint fighterBPot,
        BoutFighter winner,
        uint8[] calldata revealValues
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = getBoutOrCreate(
            boutId,
            CreateBoutParams({ setExpiryTime: false, setDefaultValuesToSaveEndBoutGas: false })
        );

        if (bout.state != BoutState.Created) {
            revert BoutInWrongStateError(boutId, bout.state);
        }

        if (winner != BoutFighter.FighterA && winner != BoutFighter.FighterB) {
            revert InvalidWinnerError(boutId, winner);
        }

        if (revealValues.length < calculateNumRevealValues(bout.numBettors)) {
            revert RevealValuesError(boutId);
        }

        if (fighterAPot.add(fighterBPot) != bout.totalPot) {
            revert PotMismatchError(boutId, fighterAPot, fighterBPot, bout.totalPot);
        }

        if (bout.expiryTime > 0 && block.timestamp >= bout.expiryTime) {
            revert BoutExpiredError(boutId, bout.expiryTime);
        }

        bout.state = BoutState.Ended;

        bout.revealValues = revealValues;

        bout.fighterIds[BoutFighter.FighterA] = fighterAId;
        bout.fighterIds[BoutFighter.FighterB] = fighterBId;

        bout.fighterPotBalances[BoutFighter.FighterA] = fighterAPot;
        bout.fighterPotBalances[BoutFighter.FighterB] = fighterBPot;

        // calculate winnings ratio
        BoutFighter loser = _getLoser(winner);
        bout.winningsRatio = (bout.fighterPotBalances[winner] > 0)
            ? ((bout.fighterPotBalances[loser] * 1000 ether) / bout.fighterPotBalances[winner])
            : 0;

        bout.winner = winner;

        bout.endTime = block.timestamp;
    }

    /*
    We usually pass maxBoutsToClaim = 1 because under normal circumstances, the user will only have one
    unclaimed bout winnings to claim. If the user places bets on lots of bouts before the 
    server suddenl goes down for a while then they'll have lots of unclaimed winnings and/or 
    bets that need to be refunded. In this case, the user may need to call this directly 
    multiple times to get through the backlog. We will enable this in the UI.
    */
    function claimWinnings(address wallet, uint maxBoutsToClaim) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint totalWinnings = 0;
        uint count = 0;

        BoutList storage c = s.userBoutsWinningsToClaimList[wallet];
        BoutListNode storage node = c.nodes[c.head];

        while (node.boutId != 0 && count < maxBoutsToClaim) {
            Bout storage bout = s.bouts[node.boutId];

            // if bout not yet ended
            if (bout.state != BoutState.Ended) {
                // if bout expired then set state to expired
                if (_isBoutExpiredOrReadyToBeMarkedAsExpired(bout)) {
                    bout.state = BoutState.Expired;
                } else {
                    // skip to next node
                    node = c.nodes[node.next];
                    count++;
                    continue;
                }
            }

            (
                uint totalToClaim,
                uint selfBetAmount,
                uint loserPotAmountToClaim
            ) = getBoutClaimableAmounts(node.boutId, wallet);

            if (totalToClaim > 0) {
                if (bout.state != BoutState.Expired) {
                    // remove bet from winner pot
                    bout.fighterPotBalances[bout.winner] = bout.fighterPotBalances[bout.winner].sub(
                        selfBetAmount
                    );
                    // remove won amount from loser pot
                    BoutFighter loser = _getLoser(bout.winner);
                    bout.fighterPotBalances[loser] = bout.fighterPotBalances[loser].sub(
                        loserPotAmountToClaim
                    );
                }

                totalWinnings = totalWinnings.add(totalToClaim);
            }

            // remove this and move to next item
            bout.bets[wallet].winningsClaimed = true;
            LibLinkedList.removeFromBoutList(s.userBoutsWinningsToClaimList[wallet], node);
            node = c.nodes[node.next];

            count++;
        }

        // transfer winnings
        if (totalWinnings > 0) {
            LibToken.transfer(LibTokenIds.TOKEN_MEME, address(this), wallet, totalWinnings);
        }
    }

    function getClaimableWinnings(
        address wallet,
        uint maxUnclaimedBouts
    ) internal view returns (uint winnings) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        BoutList storage c = s.userBoutsWinningsToClaimList[wallet];
        BoutListNode storage node = c.nodes[c.head];

        uint count = 0;

        while (node.boutId != 0 && count < maxUnclaimedBouts) {
            (uint totalToClaim, , ) = getBoutClaimableAmounts(node.boutId, wallet);
            winnings = winnings.add(totalToClaim);
            node = c.nodes[node.next];
            count++;
        }
    }

    function getBoutClaimableAmounts(
        uint boutId,
        address wallet
    ) internal view returns (uint totalToClaim, uint selfBetAmount, uint loserPotAmountToClaim) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = s.bouts[boutId];

        selfBetAmount = bout.bets[wallet].amount;

        // if bout not yet ended
        if (bout.state != BoutState.Ended) {
            // if bout expired then we just get our bet back
            if (_isBoutExpiredOrReadyToBeMarkedAsExpired(bout)) {
                totalToClaim = selfBetAmount;
                return (totalToClaim, selfBetAmount, 0);
            } else {
                // else we can't claim anything yet until bout ends
                return (0, 0, 0);
            }
        }

        // calculate which way player bet
        BoutFighter bet = getRevealedBet(bout, wallet);

        // bet on winner?
        if (bet == bout.winner) {
            // how much of losing pot do we get?
            loserPotAmountToClaim = (selfBetAmount * bout.winningsRatio) / 1000 ether;
            // total winnings
            totalToClaim = selfBetAmount + loserPotAmountToClaim;
            // return
            return (totalToClaim, selfBetAmount, loserPotAmountToClaim);
        }

        // bet on loser?
        return (0, 0, 0);
    }

    function getRevealedBet(
        Bout storage bout,
        address wallet
    ) internal view returns (BoutFighter bet) {
        // if we didn't bet in this fight then no bet exists
        if (bout.bettorIndexes[wallet] == 0) {
            return BoutFighter.Invalid;
        }

        uint index = bout.bettorIndexes[wallet] - 1;
        uint rPackedIndex = index >> 2; // 2 bits per bet => 4 bets per 8-bit reveal value

        // if index is invalid then no bet exists
        if (rPackedIndex >= bout.revealValues.length) {
            return BoutFighter.Invalid;
        }

        uint8 r = (bout.revealValues[rPackedIndex] >> ((3 - (index % 4)) * 2)) & 3;
        uint8 rawBet;
        if (bout.bets[wallet].hidden >= r) {
            rawBet = bout.bets[wallet].hidden - r;
            // ensure it's valid
            if (rawBet != 0 && rawBet != 1) {
                return BoutFighter.Invalid;
            }
        }
        bet = BoutFighter(rawBet + 1);
    }

    function calculateBetSignatureDigest(
        address server,
        address wallet,
        uint boutId,
        uint8 br,
        uint amount,
        uint deadline
    ) internal view returns (bytes32) {
        return keccak256(abi.encode(server, wallet, boutId, br, amount, deadline));
    }

    function calculateNumRevealValues(uint numBettors) internal pure returns (uint) {
        return (numBettors + 3) >> 2;
    }

    /// Private methods

    function _isBoutExpiredOrReadyToBeMarkedAsExpired(
        Bout storage bout
    ) internal view returns (bool) {
        return bout.state == BoutState.Expired || block.timestamp >= bout.expiryTime;
    }

    function _getLoser(BoutFighter winner) internal view returns (BoutFighter) {
        return winner == BoutFighter.FighterA ? BoutFighter.FighterB : BoutFighter.FighterA;
    }
}
