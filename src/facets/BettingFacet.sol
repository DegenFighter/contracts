// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { SafeMath } from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import { ERC2771Context } from "lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";

import { AppStorage, LibAppStorage, Bout, BoutState, BoutParticipant } from "../Base.sol";
import { IBettingFacet } from "../interfaces/IBettingFacet.sol";
import { Modifiers } from "../Modifiers.sol";
import { LibConstants } from "../libs/LibConstants.sol";
import { LibEip712 } from "../libs/LibEip712.sol";

contract BettingFacet is IBettingFacet, Modifiers, ERC2771Context {
    using SafeMath for uint;

    constructor() ERC2771Context(address(0)) {}

    function createBout(uint fighterA, uint fighterB) external isServer returns (uint boutNum) {
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
        return s.totalBouts;
    }

    function calculateBetSignature(address server, address supporter, uint256 boutNum, uint8 br, uint256 amount, uint256 deadline) public returns (bytes32) {
        return
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
            );
    }

    function bet(uint boutNum, uint8 br, uint amount, uint deadline, bytes memory signature) external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = s.bouts[boutNum];

        address server = s.addresses[LibConstants.SERVER_ADDRESS];

        address sender = _msgSender();

        bytes32 digest = LibEip712.hashTypedDataV4(calculateBetSignature(server, sender, boutNum, br, amount, deadline));

        address signer = LibEip712.recover(digest, signature);
        require(signer == server, "Not signed by server");
        require(block.timestamp < deadline, "Signature expired");
        require(amount >= LibConstants.MIN_SUPPORT_AMOUNT, "Not enough amount");

        require(bout.state == BoutState.Created, "Bout not in created state");
        require(br != 0, "Invalid B+R");

        // replace old bet?
        if (bout.hiddenBets[sender] != 0) {
            bout.totalPot = bout.totalPot.sub(bout.betAmounts[sender]).add(amount);
        }
        // new bet?
        else {
            bout.totalPot = bout.totalPot.add(amount);
            bout.numSupporters += 1;
            bout.supporters[bout.numSupporters] = sender;
        }
        bout.betAmounts[sender] = amount;
        bout.hiddenBets[sender] = br;

        emit BetPlaced(boutNum, sender);
    }

    function revealBets(uint boutNum, uint8[] calldata rPacked) external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        Bout storage bout = s.bouts[boutNum];

        require((bout.state == BoutState.Created && bout.numRevealedBets == 0) || (bout.state == BoutState.SupportRevealed && bout.numRevealedBets > 0), "Invalid state");
        require(bout.numRevealedBets < bout.numSupporters, "Already fully revealed");

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

        require(bout.state == BoutState.SupportRevealed, "Bout not revealed");
        require(bout.endTime == 0, "Already ended");
        require(winner == BoutParticipant.FighterA || winner == BoutParticipant.FighterB, "Invalid winner");
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
