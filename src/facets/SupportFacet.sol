// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { AppStorage, LibAppStorage, Bout, BoutState, BoutTarget } from "../Base.sol";
import { ISupportFacet } from "../interfaces/ISupportFacet.sol";
import { Modifiers } from "../Modifiers.sol";

contract SupportFacet is ISupportFacet, Modifiers {
    function createBout(uint fighterA, uint fighterB) external isServer returns (uint boutNum) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.totalBouts++;
        s.bouts[s.totalBouts].id = s.totalBouts;
        s.bouts[s.totalBouts].state = BoutState.Created;
        s.bouts[s.totalBouts].winner = BoutTarget.Unknown;
        s.bouts[s.totalBouts].loser = BoutTarget.Unknown;
        s.bouts[s.totalBouts].fighters[BoutTarget.FighterA] = fighterA;
        s.bouts[s.totalBouts].fighters[BoutTarget.FighterB] = fighterB;
        emit BoutCreated(s.totalBouts);
        return s.totalBouts;
    }

    function revealSupport(uint boutNum) external {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(s.bouts[boutNum].state == BoutState.Created, "Bout not in created state");
        require(s.bouts[boutNum].revealTime == 0, "Already revealed");
        s.bouts[boutNum].state = BoutState.SupportRevealed;
        s.bouts[boutNum].revealTime = block.timestamp;
        emit BoutSupportRevealed(boutNum);
    }

    function endBout(uint boutNum, BoutTarget winner) external {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(s.bouts[boutNum].state == BoutState.SupportRevealed, "Bout not revealed");
        require(s.bouts[boutNum].endTime == 0, "Already ended");
        require(winner == BoutTarget.FighterA || winner == BoutTarget.FighterB, "Invalid winner");
        s.bouts[boutNum].state = BoutState.Ended;
        s.bouts[boutNum].endTime = block.timestamp;
        s.bouts[boutNum].winner = winner;
        s.bouts[boutNum].loser = (winner == BoutTarget.FighterA ? BoutTarget.FighterB : BoutTarget.FighterA);
        s.boutsFinished++;
        emit BoutEnded(boutNum);
    }

    function getClaimableWinnings(address wallet) external view returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint winnings = 0;
        for (uint i = s.userBoutsClaimed[wallet] + 1; i <= s.userBoutsSupported[wallet]; i++) {
            uint boutNum = s.userBoutSupportList[wallet][i];
            (uint total, , ) = _calculateBoutWinnings(wallet, boutNum);
            winnings += total;
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
                bout.potBalances[bout.winner] -= selfAmount;
                bout.potBalances[bout.loser] -= won;
                s.memeBalance[address(this)] -= total;
                s.memeBalance[wallet] += total;
            }

            s.userBoutsClaimed[wallet]++;
        }
    }

    // Internal methods

    function _calculateBoutWinnings(address wallet, uint boutNum) private view returns (uint total, uint selfAmount, uint won) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        Bout storage bout = s.bouts[boutNum];

        if (bout.winner == s.userBoutSupportTargets[wallet][boutNum]) {
            // how much of losing pot do we get?
            uint ratio = (s.userBoutSupportAmounts[wallet][boutNum] * 1000 ether) / bout.potTotals[bout.winner];
            won = (ratio * bout.potTotals[bout.loser]) / 1000 ether;
            // how much did we put in?
            selfAmount = s.userBoutSupportAmounts[wallet][boutNum];
            // total winnings
            total = selfAmount + won;
        }
    }
}
