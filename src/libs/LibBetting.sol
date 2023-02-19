// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { SafeMath } from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

import { AppStorage, LibAppStorage, Bout, BoutState, BoutFighter, BoutList, BoutListNode } from "../Objects.sol";
import { LibToken, LibTokenIds } from "./LibToken.sol";
import { LibConstants } from "./LibConstants.sol";
import { LibEip712 } from "./LibEip712.sol";
import { LibLinkedList } from "./LibLinkedList.sol";
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
            bout.createTime = block.timestamp;
            bout.expiryTime = block.timestamp + LibConstants.DEFAULT_BOUT_EXPIRATION_TIME;
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
            LibToken.transfer(
                LibTokenIds.TOKEN_MEME,
                address(this),
                wallet,
                bout.betAmounts[wallet]
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
        bout.betAmounts[wallet] = amount;
        bout.hiddenBets[wallet] = br;

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

        Bout storage bout = getBoutOrCreate(boutId);

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

        if (block.timestamp >= bout.expiryTime) {
            revert BoutExpiredError(boutId, bout.expiryTime);
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
                    bout.fighterPotBalances[bout.loser] = bout.fighterPotBalances[bout.loser].sub(
                        loserPotAmountToClaim
                    );
                }

                totalWinnings = totalWinnings.add(totalToClaim);
            }

            // remove this and move to next item
            bout.winningsClaimed[wallet] = true;
            LibLinkedList.removeFromBoutList(s.userBoutsWinningsToClaimList[wallet], node);
            node = c.nodes[node.next];

            count++;
        }

        // transfer winnings
        if (totalWinnings > 0) {
            LibToken.transfer(LibTokenIds.TOKEN_MEME, address(this), wallet, totalWinnings);
        }
    }

    function getClaimableWinnings(address wallet) internal view returns (uint winnings) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        BoutList storage c = s.userBoutsWinningsToClaimList[wallet];
        BoutListNode storage node = c.nodes[c.head];

        while (node.boutId != 0) {
            (uint totalToClaim, , ) = getBoutClaimableAmounts(node.boutId, wallet);
            winnings = winnings.add(totalToClaim);
            node = c.nodes[node.next];
        }
    }

    function getBoutClaimableAmounts(
        uint boutId,
        address wallet
    ) internal view returns (uint totalToClaim, uint selfBetAmount, uint loserPotAmountToClaim) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = s.bouts[boutId];

        selfBetAmount = bout.betAmounts[wallet];

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
            uint ratio = (selfBetAmount * 1000 ether) / bout.fighterPots[bout.winner];
            loserPotAmountToClaim = (ratio * bout.fighterPots[bout.loser]) / 1000 ether;
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
        uint rPackedIndex = index >> 2; // 4 bets per reveal value

        // if index is invalid then no bet exists
        if (rPackedIndex >= bout.revealValues.length) {
            return BoutFighter.Invalid;
        }

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

    function calculateBetSignature(
        address server,
        address wallet,
        uint boutId,
        uint8 br,
        uint amount,
        uint deadline
    ) internal returns (bytes32) {
        return
            LibEip712.hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "calculateBetSignature(address,address,uint256,uint8,uint256,uint256)"
                        ),
                        server,
                        wallet,
                        boutId,
                        br,
                        amount,
                        deadline
                    )
                )
            );
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
}
