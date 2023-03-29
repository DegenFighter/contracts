// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import "../src/Errors.sol";
import { BoutNonMappingInfo, BoutFighter, BoutState } from "../src/Objects.sol";
import { Wallet, TestBaseContract } from "./utils/TestBaseContract.sol";
import { LibConstants } from "../src/libs/LibConstants.sol";
import { LibTokenIds } from "../src/libs/LibToken.sol";
import { LibBetting } from "../src/libs/LibBetting.sol";

contract BettingTest is TestBaseContract {
    // ------------------------------------------------------ //
    //
    // Place bet
    //
    // ------------------------------------------------------ //

    function testBetWithInvalidBoutState() public {
        uint boutId = 100;

        // do signature
        bytes32 digest = proxy.calculateBetSignatureDigest(
            server.addr,
            account0,
            boutId,
            1,
            LibConstants.MIN_BET_AMOUNT,
            block.timestamp + 1000
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        // state: Ended - should fail
        proxy._testSetBoutState(boutId, BoutState.Ended);
        vm.expectRevert(
            abi.encodePacked(BoutInWrongStateError.selector, uint(100), uint256(BoutState.Ended))
        );
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);

        // state: Expired - should fail
        proxy._testSetBoutState(boutId, BoutState.Expired);
        vm.expectRevert(
            abi.encodePacked(BoutInWrongStateError.selector, uint(100), uint256(BoutState.Expired))
        );
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetWithBadSigner() public {
        uint boutId = 100;

        // do signature
        address signer = vm.addr(123);
        bytes32 digest = proxy.calculateBetSignatureDigest(
            signer,
            account0,
            boutId,
            1,
            LibConstants.MIN_BET_AMOUNT,
            block.timestamp + 1000
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(123, digest);

        vm.expectRevert(SignerMustBeServerError.selector);
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetWithExpiredDeadline() public {
        uint boutId = 100;

        // do signature
        bytes32 digest = proxy.calculateBetSignatureDigest(
            server.addr,
            account0,
            boutId,
            1,
            LibConstants.MIN_BET_AMOUNT,
            block.timestamp - 1
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(SignatureExpiredError.selector);
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp - 1, v, r, s);
    }

    function testBetWithInsufficientBetAmount() public {
        uint boutId = 100;

        // do signature
        bytes32 digest = proxy.calculateBetSignatureDigest(
            server.addr,
            account0,
            boutId,
            1,
            LibConstants.MIN_BET_AMOUNT - 1,
            block.timestamp + 1000
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(
            abi.encodeWithSelector(
                MinimumBetAmountError.selector,
                uint(boutId),
                address(this),
                LibConstants.MIN_BET_AMOUNT - 1
            )
        );
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT - 1, block.timestamp + 1000, v, r, s);
    }

    function testBetWithInvalidBetTarget(uint8 br) public {
        vm.assume(br < 1 || br > 3); // Invalid bet target

        uint boutId = 100;

        // do signature
        bytes32 digest = proxy.calculateBetSignatureDigest(
            server.addr,
            account0,
            boutId,
            br,
            LibConstants.MIN_BET_AMOUNT,
            block.timestamp + 1000
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(
            abi.encodeWithSelector(InvalidBetTargetError.selector, boutId, address(this), br)
        );
        proxy.bet(boutId, br, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetWithInsufficentTokens() public {
        uint boutId = 100;

        uint amount = LibConstants.MIN_BET_AMOUNT + 1;

        // do signature
        bytes32 digest = proxy.calculateBetSignatureDigest(
            server.addr,
            account0,
            boutId,
            1,
            amount,
            block.timestamp + 1000
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        uint256 userBalance = proxy.tokenBalanceOf(LibTokenIds.TOKEN_MEME, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(TokenBalanceInsufficient.selector, userBalance, amount)
        );
        proxy.bet(boutId, 1, amount, block.timestamp + 1000, v, r, s);
    }

    function testBetMinimumAmountWithInsufficentTokensGetsFreeMint() public {
        uint boutId = 100;

        proxy._testMintMeme(account0, 1);
        assertEq(proxy.tokenBalanceOf(LibTokenIds.TOKEN_MEME, account0), 1);

        // do signature
        bytes32 digest = proxy.calculateBetSignatureDigest(
            server.addr,
            account0,
            boutId,
            1,
            LibConstants.MIN_BET_AMOUNT,
            block.timestamp + 1000
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);

        // check values
        assertEq(proxy.tokenBalanceOf(LibTokenIds.TOKEN_MEME, account0), 0);
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(bout.totalPot, LibConstants.MIN_BET_AMOUNT, "total pot");
    }

    function testBetSingle() public returns (uint boutId) {
        boutId = 100;

        BettingScenario memory scen = _getScenario_Default();

        // initialy no bouts
        assertEq(proxy.getTotalBouts(), 0, "no bouts at start");

        // place bet
        Wallet memory player = scen.players[0];
        _bet(player.addr, boutId, scen.betValues[0], scen.betAmounts[0]);

        // check total bouts
        assertEq(proxy.getTotalBouts(), 1, "total bouts");
        assertEq(proxy.getBoutIdByIndex(1), boutId, "bout id by index");

        // check bout basic state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(bout.state, BoutState.Created, "created");
        assertEq(
            bout.expiryTime,
            block.timestamp + LibConstants.DEFAULT_BOUT_EXPIRATION_TIME,
            "expiry time"
        );
        assertEq(bout.numBettors, 1, "no. of bettors");
        assertEq(bout.totalPot, scen.betAmounts[0], "total pot");

        // check default values
        uint8[] memory revealValues = new uint8[](1);
        assertEq(bout.revealValues, revealValues, "reveal values");
        assertEq(bout.endTime, 1, "end time");
        assertEq(bout.winner, BoutFighter.FighterA, "default winner");
        assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterA), 1, "fighter A id");
        assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterB), 1, "fighter B id");
        assertEq(proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterA), 1, "fighter A pot");
        assertEq(proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterB), 1, "fighter B pot");

        // check player data
        assertEq(proxy.getBoutSupporter(boutId, 1), player.addr, "bettor address");
        assertEq(proxy.getBoutHiddenBet(boutId, player.addr), 1, "bettor hidden bet");
        assertEq(
            proxy.getBoutBetAmount(boutId, player.addr),
            scen.betAmounts[0],
            "bettor bet amount"
        );
        assertEq(proxy.getUserBoutsBetOn(player.addr), 1, "user supported bouts");

        // check MEME balances
        assertEq(memeToken.balanceOf(player.addr), 0, "MEME balance");
        assertEq(memeToken.balanceOf(address(proxy)), bout.totalPot, "MEME balance");
    }

    function testBetMultiple() public returns (uint boutId) {
        boutId = 100;

        BettingScenario memory scen = _getScenario_Default();

        // place bets
        uint totalBetAmount = 0;
        for (uint i = 0; i < scen.players.length; i += 1) {
            Wallet memory player = scen.players[i];
            totalBetAmount += scen.betAmounts[i];
            _bet(player.addr, boutId, scen.betValues[i], scen.betAmounts[i]);
        }

        assertEq(totalBetAmount, scen.fighterAPot + scen.fighterBPot, "check total bet amount");

        // check total bouts
        assertEq(proxy.getTotalBouts(), 1, "still only 1 bout created");
        assertEq(proxy.getBoutIdByIndex(1), boutId, "bout id by index");

        // check bout basic state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(bout.numBettors, 5, "no. of bettors");
        assertEq(bout.totalPot, totalBetAmount, "total pot");

        // check bettor data
        for (uint i = 0; i < scen.players.length; i += 1) {
            Wallet memory player = scen.players[i];

            assertEq(proxy.getBoutSupporter(boutId, i + 1), player.addr, "bettor address");
            assertEq(proxy.getBoutHiddenBet(boutId, player.addr), 1, "bettor hidden bet");
            assertEq(
                proxy.getBoutBetAmount(boutId, player.addr),
                scen.betAmounts[i],
                "bettor bet amount"
            );
            assertEq(proxy.getUserBoutsBetOn(player.addr), 1, "user supported bouts");
        }

        // check MEME balances
        for (uint i = 0; i < scen.players.length; i += 1) {
            Wallet memory player = scen.players[i];
            assertEq(memeToken.balanceOf(player.addr), 0, "MEME balance");
        }
        assertEq(memeToken.balanceOf(address(proxy)), bout.totalPot, "MEME balance");
    }

    function testBetReplaceBets() public {
        uint boutId = 100;

        for (uint i = 1; i <= 5; i += 1) {
            _bet(players[0].addr, boutId, 1, LibConstants.MIN_BET_AMOUNT * i);
        }

        // check bout basic state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(bout.state, BoutState.Created, "created");
        assertEq(bout.numBettors, 1, "no. of bettors");
        assertEq(bout.totalPot, LibConstants.MIN_BET_AMOUNT * 5, "total pot");

        // check bettor data
        assertEq(proxy.getBoutSupporter(boutId, 1), players[0].addr, "bettor address");
        assertEq(proxy.getBoutHiddenBet(boutId, players[0].addr), 1, "bettor hidden bet");
        assertEq(
            proxy.getBoutBetAmount(boutId, players[0].addr),
            bout.totalPot,
            "bettor bet amount"
        );
        assertEq(proxy.getUserBoutsBetOn(players[0].addr), 1, "user supported bouts");

        // check MEME balances
        assertEq(
            memeToken.balanceOf(players[0].addr),
            LibConstants.MIN_BET_AMOUNT * 10,
            "MEME balance"
        );
        assertEq(memeToken.balanceOf(address(proxy)), bout.totalPot, "MEME balance");
    }

    function testBetEmitsEvent() public {
        uint boutId = 100;

        uint amount = LibConstants.MIN_BET_AMOUNT;

        vm.recordLogs();

        _bet(players[0].addr, boutId, 1, amount);

        // check logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 3, "Invalid entry count");
        assertEq(entries[2].topics.length, 1, "Invalid event count");
        assertEq(
            entries[2].topics[0],
            keccak256("BetPlaced(uint256,address)"),
            "Invalid event signature"
        );
        (uint eBoutId, address bettor) = abi.decode(entries[2].data, (uint256, address));
        assertEq(eBoutId, boutId, "boutId incorrect");
        assertEq(bettor, players[0].addr, "bettor incorrect");
    }

    // ------------------------------------------------------ //
    //
    // End bout
    //
    // ------------------------------------------------------ //

    function testEndBoutMustBeDoneByServer() public {
        uint boutId = testBetMultiple();

        BettingScenario memory scen = _getScenario_Default();

        address dummyServer = vm.addr(123);

        vm.prank(dummyServer);
        vm.expectRevert(CallerMustBeServerError.selector);
        proxy.endBout(
            boutId,
            21,
            22,
            scen.fighterAPot,
            scen.fighterBPot,
            scen.winner,
            scen.revealValues
        );

        proxy.setAddress(LibConstants.SERVER_ADDRESS, dummyServer);

        vm.prank(dummyServer);
        proxy.endBout(
            boutId,
            21,
            22,
            scen.fighterAPot,
            scen.fighterBPot,
            scen.winner,
            scen.revealValues
        );
    }

    function testEndBoutWithInvalidState() public {
        uint boutId = testBetMultiple();

        BettingScenario memory scen = _getScenario_Default();

        vm.startPrank(server.addr);

        // state: Ended - fails
        proxy._testSetBoutState(boutId, BoutState.Ended);
        vm.expectRevert(
            abi.encodeWithSelector(BoutInWrongStateError.selector, boutId, BoutState.Ended)
        );
        proxy.endBout(
            boutId,
            21,
            22,
            scen.fighterAPot,
            scen.fighterBPot,
            scen.winner,
            scen.revealValues
        );

        vm.stopPrank();
    }

    function testEndBoutWithInvalidWinner() public {
        uint boutId = testBetMultiple();

        BettingScenario memory scen = _getScenario_Default();

        vm.prank(server.addr);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidWinnerError.selector, boutId, BoutFighter.Invalid)
        );
        proxy.endBout(
            boutId,
            21,
            22,
            scen.fighterAPot,
            scen.fighterBPot,
            BoutFighter.Invalid,
            scen.revealValues
        );
    }

    function testEndBoutWithPotMismatch() public {
        uint boutId = testBetMultiple();

        BettingScenario memory scen = _getScenario_Default();

        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);

        vm.prank(server.addr);
        vm.expectRevert(
            abi.encodeWithSelector(
                PotMismatchError.selector,
                boutId,
                scen.fighterAPot - 1,
                scen.fighterBPot,
                bout.totalPot
            )
        );
        proxy.endBout(
            boutId,
            21,
            22,
            scen.fighterAPot - 1,
            scen.fighterBPot,
            scen.winner,
            scen.revealValues
        );
    }

    function testEndBoutWithInsufficientRevealValues() public {
        uint boutId = testBetMultiple();

        BettingScenario memory scen = _getScenario_Default();

        uint8[] memory badRevealValues = new uint8[](1);

        vm.prank(server.addr);
        vm.expectRevert(abi.encodeWithSelector(RevealValuesError.selector, boutId));
        proxy.endBout(
            boutId,
            21,
            22,
            scen.fighterAPot,
            scen.fighterBPot,
            scen.winner,
            badRevealValues
        );
    }

    function testEndBout() public returns (uint boutId) {
        boutId = testBetMultiple();

        BettingScenario memory scen = _getScenario_Default();

        vm.prank(server.addr);
        proxy.endBout(
            boutId,
            21,
            22,
            scen.fighterAPot,
            scen.fighterBPot,
            scen.winner,
            scen.revealValues
        );

        // check the state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(bout.state, BoutState.Ended, "state");
        assertGt(bout.endTime, 0, "end time");
        assertEq(bout.winner, scen.winner, "winner");
        assertEq(bout.revealValues, scen.revealValues, "reveal values");
        assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterA), 21, "fighter A id");
        assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterB), 22, "fighter B id");
        assertEq(
            proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterA),
            scen.fighterAPot,
            "fighter A pot balance"
        );
        assertEq(
            proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterB),
            scen.fighterBPot,
            "fighter B pot balance"
        );
    }

    function testEndBoutCreatesBoutIfNeeded() public {
        uint boutId = 100; // doesn't exist

        BettingScenario memory scen = _getScenario_Default();

        uint8[] memory emptyRevealValues;

        vm.prank(server.addr);
        proxy.endBout(boutId, 21, 22, 0, 0, scen.winner, emptyRevealValues);

        // check total bouts
        assertEq(proxy.getTotalBouts(), 1, "total bouts");
        assertEq(proxy.getBoutIdByIndex(1), boutId, "bout id by index");

        // check bout state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(bout.state, BoutState.Ended, "state");
        assertEq(bout.expiryTime, 0, "no expiry time");
        assertGt(bout.endTime, 0, "end time");
        assertEq(bout.totalPot, 0, "total pot");
        assertEq(bout.revealValues, emptyRevealValues, "reveal values");
        assertEq(bout.winner, scen.winner, "winner");

        assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterA), 21, "fighter A id");
        assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterB), 22, "fighter B id");
        assertEq(
            proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterA),
            0,
            "fighter A pot balance"
        );
        assertEq(
            proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterB),
            0,
            "fighter B pot balance"
        );
    }

    function testEndBoutEmitsEvent() public {
        uint boutId = testBetMultiple();

        BettingScenario memory scen = _getScenario_Default();

        vm.recordLogs();

        vm.prank(server.addr);
        proxy.endBout(
            boutId,
            21,
            22,
            scen.fighterAPot,
            scen.fighterBPot,
            scen.winner,
            scen.revealValues
        );

        // check logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1, "Invalid event count");
        assertEq(entries[0].topics[0], keccak256("BoutEnded(uint256)"));
        uint eBoutId = abi.decode(entries[0].data, (uint));
        assertEq(eBoutId, boutId, "boutId incorrect");
    }

    function testEndBoutRevealsBetsCorrectly() public returns (uint boutId) {
        boutId = 100;

        BettingScenario memory scen = _getScenario_Default();

        // place bets
        uint totalBetAmount = 0;
        for (uint i = 0; i < scen.players.length; i += 1) {
            Wallet memory player = scen.players[i];
            totalBetAmount += scen.betAmounts[i];
            _bet(player.addr, boutId, scen.betValues[i], scen.betAmounts[i]);
        }

        vm.prank(server.addr);
        proxy.endBout(
            boutId,
            21,
            22,
            scen.fighterAPot,
            scen.fighterBPot,
            scen.winner,
            scen.revealValues
        );

        uint8[] memory revealValues = proxy.getBoutNonMappingInfo(boutId).revealValues;

        // check the state
        assertEq(revealValues, scen.revealValues, "reveal values");

        // check revealed bets
        for (uint i = 0; i < scen.players.length; i++) {
            Wallet memory player = scen.players[i];

            BoutFighter revealedBet = proxy.getBoutRevealedBet(boutId, player.addr);

            assertEq(revealedBet, scen.betTargets[i], "revealed target");
        }
    }

    function testEndBoutAndRevealedBetForNonBettor() public {
        uint boutId = testBetMultiple();

        BettingScenario memory scen = _getScenario_Default();

        vm.prank(server.addr);
        proxy.endBout(
            boutId,
            21,
            22,
            scen.fighterAPot,
            scen.fighterBPot,
            scen.winner,
            scen.revealValues
        );

        BoutFighter revealedBet = proxy.getBoutRevealedBet(boutId, vm.addr(666));
        assertEq(revealedBet, BoutFighter.Invalid, "no target");
    }

    // ------------------------------------------------------ //
    //
    // Test processing multiple bouts
    //
    // ------------------------------------------------------ //

    function testProcessMultipleBoutsInSequence() public returns (uint[] memory boutIds) {
        BettingScenario memory scen = _getScenario_Default();

        uint numBouts = 5;

        boutIds = new uint[](numBouts);

        for (uint i = 0; i < numBouts; i += 1) {
            boutIds[i] = 100 + i;

            for (uint j = 0; j < scen.players.length; j += 1) {
                _bet(scen.players[j].addr, boutIds[i], scen.betValues[j], scen.betAmounts[j]);
            }

            assertEq(proxy.getTotalBouts(), i + 1, "total bouts");

            vm.prank(server.addr);
            proxy.endBout(
                boutIds[i],
                21,
                22,
                scen.fighterAPot,
                scen.fighterBPot,
                scen.winner,
                scen.revealValues
            );
        }

        for (uint i = 0; i < numBouts; i += 1) {
            uint boutId = boutIds[i];
            // check bout state
            BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
            assertEq(bout.state, BoutState.Ended, "state");
            assertGt(bout.endTime, 0, "end time");
            assertEq(bout.totalPot, scen.fighterAPot + scen.fighterBPot, "total pot");
            assertEq(bout.revealValues, scen.revealValues, "reveal values");
            assertEq(bout.winner, scen.winner, "winner");
            assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterA), 21, "fighter A id");
            assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterB), 22, "fighter B id");
            /*
                For all bouts except the last one, the fighter pot balance should be 0 or close to 0
                since we claim winnings when placing bets
            */
            if (i < numBouts - 1) {
                assertLt(
                    proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterA),
                    1000,
                    "fighter A pot balance"
                );
                assertLt(
                    proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterB),
                    1000,
                    "fighter B pot balance"
                );
            } else {
                assertEq(
                    proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterA),
                    scen.fighterAPot,
                    "fighter A pot balance"
                );
                assertEq(
                    proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterB),
                    scen.fighterBPot,
                    "fighter B pot balance"
                );
            }
        }
    }

    function testProcessMultipleBoutsInParallel() public returns (uint[] memory boutIds) {
        BettingScenario memory scen = _getScenario_Default();

        uint numBouts = 5;

        boutIds = new uint[](numBouts);

        for (uint i = 0; i < numBouts; i += 1) {
            boutIds[i] = 100 + i;

            for (uint j = 0; j < scen.players.length; j += 1) {
                _bet(scen.players[j].addr, boutIds[i], scen.betValues[j], scen.betAmounts[j]);
            }
        }

        assertEq(proxy.getTotalBouts(), numBouts, "total bouts");

        for (uint i = 0; i < numBouts; i += 1) {
            vm.prank(server.addr);
            proxy.endBout(
                boutIds[i],
                21,
                22,
                scen.fighterAPot,
                scen.fighterBPot,
                scen.winner,
                scen.revealValues
            );
        }

        for (uint i = 0; i < numBouts; i += 1) {
            uint boutId = boutIds[i];
            // check bout state
            BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
            assertEq(bout.state, BoutState.Ended, "state");
            assertGt(bout.endTime, 0, "end time");
            assertEq(bout.totalPot, scen.fighterAPot + scen.fighterBPot, "total pot");
            assertEq(bout.revealValues, scen.revealValues, "reveal values");
            assertEq(bout.winner, scen.winner, "winner");

            assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterA), 21, "fighter A id");
            assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterB), 22, "fighter B id");

            assertEq(
                proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterA),
                scen.fighterAPot,
                "fighter A pot balance"
            );
            assertEq(
                proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterB),
                scen.fighterBPot,
                "fighter B pot balance"
            );
        }
    }

    // ------------------------------------------------------ //
    //
    // Get Claimable winnings - successfully completed bouts
    //
    // ------------------------------------------------------ //

    function testGetClaimableWinningsBeforeBoutEnded() public {
        uint boutId = testBetMultiple();

        BettingScenario memory scen = _getScenario_Default();

        // check claimable winnings
        for (uint i = 0; i < scen.players.length; i++) {
            Wallet memory player = scen.players[i];

            uint winnings = proxy.getClaimableWinnings(player.addr);
            assertEq(winnings, 0, "no winnings claimable yet");

            (uint total, uint selfAmount, uint won) = proxy.getBoutClaimableAmounts(
                boutId,
                player.addr
            );
            assertEq(total, 0, "no total winnings");
            assertEq(selfAmount, 0, "no bet amound refundable");
            assertEq(won, 0, "no winnings");
        }
    }

    function testGetClaimableWinningsForBoutWeDidNotBetIn() public {
        uint boutId = testEndBout();

        BettingScenario memory scen = _getScenario_Default();

        address playerAddr = vm.addr(666);

        assertEq(proxy.getClaimableWinnings(playerAddr), 0, "no winnings claimable");

        (uint total, uint selfAmount, uint won) = proxy.getBoutClaimableAmounts(boutId, playerAddr);
        assertEq(total, 0, "no total winnings");
        assertEq(selfAmount, 0, "no bet amound refundable");
        assertEq(won, 0, "no winnings");
    }

    function testGetClaimableWinningsForSingleBout() public {
        uint boutId = testEndBout();

        BettingScenario memory scen = _getScenario_Default();

        // check claimable winnings
        for (uint i = 0; i < scen.players.length; i++) {
            Wallet memory player = scen.players[i];

            uint winnings = proxy.getClaimableWinnings(player.addr);

            assertEq(winnings, scen.expectedWinnings[i], "winnings");
        }
    }

    function testGetClaimableWinningsForMultipleBouts() public {
        uint[] memory boutIds = testProcessMultipleBoutsInParallel();

        BettingScenario memory scen = _getScenario_Default();

        // check claimable winnings
        for (uint i = 1; i < 2; i++) {
            Wallet memory player = scen.players[i];

            uint winnings = proxy.getClaimableWinnings(player.addr);

            assertEq(winnings, scen.expectedWinnings[i] * boutIds.length, "winnings");
        }
    }

    function testGetClaimableWinningsWhenAllBetsAreOnLoser() public {
        BettingScenario memory scen = _getScenario_AllOnLoser();

        uint boutId = 100;

        for (uint j = 0; j < scen.players.length; j += 1) {
            _bet(scen.players[j].addr, boutId, scen.betValues[j], scen.betAmounts[j]);
        }

        vm.prank(server.addr);
        proxy.endBout(
            boutId,
            21,
            22,
            scen.fighterAPot,
            scen.fighterBPot,
            scen.winner,
            scen.revealValues
        );

        // check claimable winnings
        for (uint i = 0; i < scen.players.length; i++) {
            Wallet memory player = scen.players[i];

            uint winnings = proxy.getClaimableWinnings(player.addr);

            assertEq(winnings, scen.expectedWinnings[i], "winnings");
        }
    }

    function testGetClaimableWinningsWhenAllBetsAreOnWinner() public {
        BettingScenario memory scen = _getScenario_AllOnWinner();

        uint boutId = 100;

        for (uint j = 0; j < scen.players.length; j += 1) {
            _bet(scen.players[j].addr, boutId, scen.betValues[j], scen.betAmounts[j]);
        }

        vm.prank(server.addr);
        proxy.endBout(
            boutId,
            21,
            22,
            scen.fighterAPot,
            scen.fighterBPot,
            scen.winner,
            scen.revealValues
        );

        // check claimable winnings
        for (uint i = 0; i < scen.players.length; i++) {
            Wallet memory player = scen.players[i];

            uint winnings = proxy.getClaimableWinnings(player.addr);

            assertEq(winnings, scen.expectedWinnings[i], "winnings");
        }
    }

    // ------------------------------------------------------ //
    //
    //  Claimable winnings get included in "available" MEME
    //
    // ------------------------------------------------------ //

    function testGetClaimableWinningsIncludedInAvailableMeme() public {
        uint boutId = testEndBout();

        BettingScenario memory scen = _getScenario_Default();

        // check claimable winnings
        for (uint i = 0; i < scen.players.length; i++) {
            Wallet memory player = scen.players[i];

            proxy._testMintMeme(player.addr, 1000 + i);

            uint winnings = proxy.getClaimableWinnings(player.addr);

            uint availMeme = proxy.getAvailableMeme(player.addr);

            assertEq(availMeme, winnings + 1000 + i, "winnings");
        }
    }

    // ------------------------------------------------------ //
    //
    //  Claim winnings - successfully completed bouts
    //
    // ------------------------------------------------------ //

    // use this to avoid stack too deep errors
    struct ClaimWinningsLoopValues {
        uint winnerPotPrevBalance;
        uint loserPotPrevBalance;
        uint winnerPotPostBalance;
        uint loserPotPostBalance;
        uint proxyMemeTokenBalance;
        uint total;
        uint selfAmount;
        uint won;
    }

    function testClaimWinningsForSingleBout() public {
        uint boutId = testEndBout();

        BettingScenario memory scen = _getScenario_Default();

        ClaimWinningsLoopValues memory v;
        Wallet memory player;

        // check claimable winnings
        for (uint i = 0; i < scen.players.length; i++) {
            player = scen.players[i];

            // get fighter pot balances
            v.winnerPotPrevBalance = proxy.getBoutFighterPotBalance(boutId, scen.winner);
            v.loserPotPrevBalance = proxy.getBoutFighterPotBalance(boutId, scen.loser);

            // get meme token balance of proxy
            v.proxyMemeTokenBalance = memeToken.balanceOf(proxyAddress);

            // get bout winnings for this player
            (v.total, v.selfAmount, v.won) = proxy.getBoutClaimableAmounts(boutId, player.addr);

            // make claim
            proxy.claimWinnings(player.addr, 1);

            // check fighter pot balances
            v.winnerPotPostBalance = proxy.getBoutFighterPotBalance(boutId, scen.winner);
            v.loserPotPostBalance = proxy.getBoutFighterPotBalance(boutId, scen.loser);
            if (scen.betTargets[i] == scen.winner) {
                assertEq(v.winnerPotPostBalance, v.winnerPotPrevBalance - v.selfAmount);
                assertEq(v.loserPotPostBalance, v.loserPotPrevBalance - v.won);
            } else {
                assertEq(v.winnerPotPostBalance, v.winnerPotPrevBalance);
                assertEq(v.loserPotPostBalance, v.loserPotPrevBalance);
            }

            // check bout winnings claimed status
            assertEq(
                proxy.getBoutWinningsClaimed(boutId, player.addr),
                true,
                "bout winnings claimed"
            );

            // check that tokens were transferred
            assertEq(memeToken.balanceOf(player.addr), v.total, "total winnings");
            assertEq(
                memeToken.balanceOf(proxyAddress),
                v.proxyMemeTokenBalance - v.total,
                "proxy meme token balance"
            );

            // check that there no more winnings to claim for this player
            assertEq(proxy.getClaimableWinnings(player.addr), 0, "all winnings claimed");
        }
    }

    function testClaimWinningsForMultipleBouts() public {
        uint[] memory boutIds = testProcessMultipleBoutsInParallel();

        BettingScenario memory scen = _getScenario_Default();

        ClaimWinningsLoopValues[] memory v = new ClaimWinningsLoopValues[](boutIds.length);
        Wallet memory player = scen.players[2];
        assertEq(scen.betTargets[2], scen.winner, "chosen winner");

        uint winningsClaimed = 0;
        uint totalWinnings = proxy.getClaimableWinnings(player.addr);
        uint proxyMemeTokenBalance = memeToken.balanceOf(proxyAddress);

        // get pre-values
        for (uint i = 0; i < boutIds.length; i++) {
            uint boutId = boutIds[i];

            // get fighter pot balances
            v[i].winnerPotPrevBalance = proxy.getBoutFighterPotBalance(boutId, scen.winner);
            v[i].loserPotPrevBalance = proxy.getBoutFighterPotBalance(boutId, scen.loser);

            // get bout winnings for this player
            (v[i].total, v[i].selfAmount, v[i].won) = proxy.getBoutClaimableAmounts(
                boutId,
                player.addr
            );

            winningsClaimed += v[i].total;
        }

        // have winnings to claim
        assertGt(winningsClaimed, 0, "have winnings to claim");
        assertEq(winningsClaimed, totalWinnings, "have winnings to claim equal to total");

        // make claim
        proxy.claimWinnings(player.addr, boutIds.length);

        // check post-values
        for (uint i = 0; i < boutIds.length; i++) {
            uint boutId = boutIds[i];

            // check fighter pot balances
            v[i].winnerPotPostBalance = proxy.getBoutFighterPotBalance(boutId, scen.winner);
            v[i].loserPotPostBalance = proxy.getBoutFighterPotBalance(boutId, scen.loser);
            assertEq(v[i].winnerPotPostBalance, v[i].winnerPotPrevBalance - v[i].selfAmount);
            assertEq(v[i].loserPotPostBalance, v[i].loserPotPrevBalance - v[i].won);

            // check bout winnings claimed status
            assertEq(
                proxy.getBoutWinningsClaimed(boutId, player.addr),
                true,
                "bout winnings claimed"
            );
        }

        // check that tokens were transferred
        assertEq(memeToken.balanceOf(player.addr), winningsClaimed, "total winnings");
        assertEq(
            memeToken.balanceOf(proxyAddress),
            proxyMemeTokenBalance - winningsClaimed,
            "proxy meme token balance"
        );

        // check that there no more winnings to claim for this player
        assertEq(proxy.getClaimableWinnings(player.addr), 0, "all winnings claimed");
    }

    function testClaimWinningsForMultipleBoutsSubset() public {
        uint[] memory boutIds = testProcessMultipleBoutsInParallel();

        BettingScenario memory scen = _getScenario_Default();

        ClaimWinningsLoopValues[] memory v = new ClaimWinningsLoopValues[](boutIds.length);
        Wallet memory player = scen.players[2];
        assertEq(scen.betTargets[2], scen.winner, "chosen winner");

        uint winningsClaimed = 0;
        uint totalWinnings = proxy.getClaimableWinnings(player.addr);
        uint proxyMemeTokenBalance = memeToken.balanceOf(proxyAddress);

        uint MAX_BOUTS = 2;

        // get pre-values
        for (uint i = 0; i < MAX_BOUTS; i++) {
            uint boutId = boutIds[i];

            // get fighter pot balances
            v[i].winnerPotPrevBalance = proxy.getBoutFighterPotBalance(boutId, scen.winner);
            v[i].loserPotPrevBalance = proxy.getBoutFighterPotBalance(boutId, scen.loser);

            // get bout winnings for this player
            (v[i].total, v[i].selfAmount, v[i].won) = proxy.getBoutClaimableAmounts(
                boutId,
                player.addr
            );

            winningsClaimed += v[i].total;
        }

        assertGt(winningsClaimed, 0, "have winnings to claim");
        assertLt(winningsClaimed, totalWinnings, "have winnings to claim less than total");

        // make claim
        proxy.claimWinnings(player.addr, MAX_BOUTS);

        // check post-values
        for (uint i = 0; i < MAX_BOUTS; i++) {
            uint boutId = boutIds[i];

            // check fighter pot balances
            v[i].winnerPotPostBalance = proxy.getBoutFighterPotBalance(boutId, scen.winner);
            v[i].loserPotPostBalance = proxy.getBoutFighterPotBalance(boutId, scen.loser);
            assertEq(v[i].winnerPotPostBalance, v[i].winnerPotPrevBalance - v[i].selfAmount);
            assertEq(v[i].loserPotPostBalance, v[i].loserPotPrevBalance - v[i].won);

            // check bout winnings claimed status
            assertEq(
                proxy.getBoutWinningsClaimed(boutId, player.addr),
                true,
                "bout winnings claimed"
            );
        }

        // check that tokens were transferred
        assertEq(memeToken.balanceOf(player.addr), winningsClaimed, "total winnings");
        assertEq(
            memeToken.balanceOf(proxyAddress),
            proxyMemeTokenBalance - winningsClaimed,
            "proxy meme token balance"
        );

        assertEq(proxy.getUserBoutsWinningsClaimed(player.addr), 2, "bouts claimed");

        // check that there are still winnings to claim for this player
        assertEq(
            proxy.getClaimableWinnings(player.addr),
            totalWinnings - winningsClaimed,
            "some winnings claimed"
        );
    }

    // ------------------------------------------------------ //
    //
    // Expired bouts
    //
    // ------------------------------------------------------ //

    function testEndBoutWhenExpired() public {
        uint boutId = testBetMultiple();

        uint expiryTime = proxy.getBoutNonMappingInfo(boutId).expiryTime;

        // move to past expiry
        vm.warp(expiryTime);

        BettingScenario memory scen = _getScenario_Default();

        vm.prank(server.addr);
        vm.expectRevert(abi.encodeWithSelector(BoutExpiredError.selector, boutId, expiryTime));
        proxy.endBout(
            boutId,
            21,
            22,
            scen.fighterAPot,
            scen.fighterBPot,
            scen.winner,
            scen.revealValues
        );
    }

    function testGetClaimableWinningsForExpiredBout() public {
        uint boutId = testBetMultiple();

        uint expiryTime = proxy.getBoutNonMappingInfo(boutId).expiryTime;

        // move to past expiry
        vm.warp(expiryTime);

        BettingScenario memory scen = _getScenario_Default();

        // check claimable winnings
        for (uint i = 0; i < scen.players.length; i++) {
            Wallet memory player = scen.players[i];

            uint winnings = proxy.getClaimableWinnings(player.addr);
            assertEq(winnings, scen.betAmounts[i], "bet refunded");

            (uint total, uint selfAmount, uint won) = proxy.getBoutClaimableAmounts(
                boutId,
                player.addr
            );
            assertEq(total, selfAmount, "bet refunded - 2");
            assertEq(won, 0, "no winnings");
        }
    }

    function testClaimWinningsForExpiredBout() public {
        uint boutId = testBetMultiple();

        uint expiryTime = proxy.getBoutNonMappingInfo(boutId).expiryTime;

        // move to past expiry
        vm.warp(expiryTime);

        BettingScenario memory scen = _getScenario_Default();

        Wallet memory player = scen.players[2];
        assertEq(scen.betTargets[2], scen.winner, "bet target");

        uint totalWinnings = proxy.getClaimableWinnings(player.addr);
        uint proxyMemeTokenBalance = memeToken.balanceOf(proxyAddress);
        ClaimWinningsLoopValues memory v;

        // get bout winnings for this player
        (v.total, v.selfAmount, v.won) = proxy.getBoutClaimableAmounts(boutId, player.addr);

        // make claim
        proxy.claimWinnings(player.addr, 1);

        // check bout winnings claimed status
        assertEq(proxy.getBoutWinningsClaimed(boutId, player.addr), true, "bout winnings claimed");

        // check that tokens were transferred
        assertEq(memeToken.balanceOf(player.addr), v.total, "total winnings");
        assertEq(
            memeToken.balanceOf(proxyAddress),
            proxyMemeTokenBalance - v.total,
            "proxy meme token balance"
        );

        // check that there no more winnings to claim for this player
        assertEq(proxy.getClaimableWinnings(player.addr), 0, "all winnings claimed");

        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(bout.state, BoutState.Expired, "bout state");
    }

    function testClaimWinningsForExpiredAndEndedBouts() public {
        BettingScenario memory scen = _getScenario_Default();

        uint numBouts = 5;

        uint[] memory boutIds = new uint[](numBouts);

        for (uint i = 0; i < numBouts; i += 1) {
            boutIds[i] = 100 + i;

            for (uint j = 0; j < scen.players.length; j += 1) {
                _bet(scen.players[j].addr, boutIds[i], scen.betValues[j], scen.betAmounts[j]);
            }

            proxy._testSetBoutExpiryTime(boutIds[i], block.timestamp + 100 * (i + 1));
        }

        // move past expiry of 1st bout
        vm.warp(block.timestamp + 100);

        // end the 3rd bout
        vm.prank(server.addr);
        proxy.endBout(
            boutIds[2],
            21,
            23,
            scen.fighterAPot,
            scen.fighterBPot,
            scen.winner,
            scen.revealValues
        );

        // at this point, bouts 2, 4, and 5 have yet to be ended

        Wallet memory player = scen.players[2];
        assertEq(scen.betTargets[2], scen.winner, "bet target");

        uint totalWinnings = proxy.getClaimableWinnings(player.addr);
        uint proxyMemeTokenBalance = memeToken.balanceOf(proxyAddress);
        ClaimWinningsLoopValues memory v;

        // make claim
        proxy.claimWinnings(player.addr, 10);

        // check bout winnings claimed status
        assertEq(proxy.getBoutWinningsClaimed(boutIds[0], player.addr), true, "bout 1 claimed");
        assertEq(
            proxy.getBoutWinningsClaimed(boutIds[1], player.addr),
            false,
            "bout 2 not claimed"
        );
        assertEq(proxy.getBoutWinningsClaimed(boutIds[2], player.addr), true, "bout 3 claimed");
        assertEq(
            proxy.getBoutWinningsClaimed(boutIds[3], player.addr),
            false,
            "bout 4 not claimed"
        );
        assertEq(
            proxy.getBoutWinningsClaimed(boutIds[4], player.addr),
            false,
            "bout 5 not claimed"
        );

        // check that tokens were transferred
        assertEq(memeToken.balanceOf(player.addr), totalWinnings, "total winnings");
        assertEq(
            memeToken.balanceOf(proxyAddress),
            proxyMemeTokenBalance - totalWinnings,
            "proxy meme token balance"
        );

        // check that there no more winnings to claim for this player
        assertEq(proxy.getClaimableWinnings(player.addr), 0, "all winnings claimed");

        // check that user bout winningsToClaim list is now of length 3
        assertEq(
            proxy._testGetUserWinningsToClaimListLength(player.addr),
            3,
            "winnings to claim length"
        );
    }

    // ------------------------------------------------------ //
    //
    // Private/internal methods
    //
    // ------------------------------------------------------ //

    function _bet(address bettor, uint boutId, uint8 br, uint amount) internal {
        // mint tokens
        proxy._testMintMeme(bettor, amount);

        // do signature
        bytes32 digest = proxy.calculateBetSignatureDigest(
            server.addr,
            bettor,
            boutId,
            br,
            amount,
            block.timestamp + 1000
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.prank(bettor);
        proxy.bet(boutId, br, amount, block.timestamp + 1000, v, r, s);
    }

    struct BettingScenario {
        Wallet[] players;
        uint[] betAmounts;
        uint8[] betValues;
        BoutFighter[] betTargets;
        uint fighterAPot;
        uint fighterBPot;
        uint8[] revealValues;
        BoutFighter winner;
        BoutFighter loser;
        uint[] expectedWinnings;
    }

    // 5 players, 3 bet on the loser, 2 on the winner
    function _getScenario_Default() internal returns (BettingScenario memory scen) {
        uint LEN = 5;

        scen.winner = BoutFighter.FighterB;
        scen.loser = BoutFighter.FighterA;
        scen.betTargets = new BoutFighter[](LEN);
        for (uint i = 0; i < LEN; i++) {
            scen.betTargets[i] = (i == 0 || i == 1 || i == 4) ? scen.loser : scen.winner;
        }

        scen = __buildScenario(scen);
    }

    // 5 players, all bet on the loser
    function _getScenario_AllOnLoser() internal returns (BettingScenario memory scen) {
        uint LEN = 5;

        scen.winner = BoutFighter.FighterB;
        scen.loser = BoutFighter.FighterA;
        scen.betTargets = new BoutFighter[](LEN);
        for (uint i = 0; i < LEN; i++) {
            scen.betTargets[i] = scen.loser;
        }

        scen = __buildScenario(scen);

        for (uint i = 0; i < LEN; i++) {
            assertEq(scen.expectedWinnings[i], 0, "expected winnings is 0");
        }
    }

    // 5 players, all bet on the winner
    function _getScenario_AllOnWinner() internal returns (BettingScenario memory scen) {
        uint LEN = 5;

        scen.winner = BoutFighter.FighterB;
        scen.loser = BoutFighter.FighterA;
        scen.betTargets = new BoutFighter[](LEN);
        for (uint i = 0; i < LEN; i++) {
            scen.betTargets[i] = scen.winner;
        }

        scen = __buildScenario(scen);

        for (uint i = 0; i < LEN; i++) {
            assertEq(scen.expectedWinnings[i], scen.betAmounts[i], "expected winnings same as bet");
        }
    }

    function __buildScenario(
        BettingScenario memory scen
    ) internal returns (BettingScenario memory) {
        uint LEN = scen.betTargets.length;

        scen.players = new Wallet[](LEN);

        for (uint i = 0; i < LEN; i++) {
            scen.players[i] = players[i];
        }

        scen.betAmounts = new uint[](LEN);
        scen.betValues = new uint8[](LEN);
        scen.revealValues = new uint8[](LibBetting.calculateNumRevealValues(LEN));

        uint winningPot;
        uint losingPot;
        uint revealIndex = 0;
        uint8 revealValue = 0;

        for (uint8 i = 0; i < uint8(LEN); i++) {
            scen.betAmounts[i] = LibConstants.MIN_BET_AMOUNT * (i + 1);
            scen.betValues[i] = 1;

            // move to next uint8 if needed
            uint newRevealIndex = i >> 2;
            if (newRevealIndex > revealIndex) {
                scen.revealValues[revealIndex] = revealValue;
                revealValue = 0;
                revealIndex = newRevealIndex;
            }

            if (scen.betTargets[i] == scen.winner) {
                winningPot += scen.betAmounts[i];
                // reveal value = 0 since betValue = 1 and betTarget = 1 (fighter B)
            } else {
                losingPot += scen.betAmounts[i];
                // reveal value = 1 since betValue = 1 and betTarget = 0 (fighter A)
                revealValue |= (uint8(1) << ((3 - (i % 4)) * 2));
            }
        }

        // set last reveal value
        scen.revealValues[revealIndex] = revealValue;

        // set pots
        scen.fighterBPot = winningPot;
        scen.fighterAPot = losingPot;

        // expected winnings
        scen.expectedWinnings = new uint[](LEN);
        for (uint i = 0; i < LEN; i++) {
            if (scen.betTargets[i] == scen.loser) {
                scen.expectedWinnings[i] = 0;
            } else {
                scen.expectedWinnings[i] =
                    scen.betAmounts[i] +
                    ((((scen.betAmounts[i] * 1000 ether) / winningPot) * losingPot) / 1000 ether);
            }
        }

        return scen;
    }
}
