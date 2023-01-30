// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import "../src/Errors.sol";
import { BoutNonMappingInfo, BoutFighter, BoutState } from "../src/Objects.sol";
import { Wallet, TestBaseContract } from "./utils/TestBaseContract.sol";
import { LibConstants } from "../src/libs/LibConstants.sol";
import { LibTokenIds } from "../src/libs/LibToken.sol";

contract BettingTest is TestBaseContract {
    uint fighterAId = 1;
    uint fighterBId = 2;

    function setUp() public override {
        super.setUp();
    }

    // ------------------------------------------------------ //
    //
    // Place bet
    //
    // ------------------------------------------------------ //

    function testBetWithInvalidBoutState() public {
        uint boutId = 100;

        // do signature
        bytes32 digest = proxy.calculateBetSignature(
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
        bytes32 digest = proxy.calculateBetSignature(
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
        bytes32 digest = proxy.calculateBetSignature(
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
        bytes32 digest = proxy.calculateBetSignature(
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
        bytes32 digest = proxy.calculateBetSignature(
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

        // do signature
        bytes32 digest = proxy.calculateBetSignature(
            server.addr,
            account0,
            boutId,
            1,
            LibConstants.MIN_BET_AMOUNT,
            block.timestamp + 1000
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        uint256 userBalance = proxy.tokenBalanceOf(LibTokenIds.TOKEN_MEME, address(this));

        vm.expectRevert(
            abi.encodeWithSelector(
                TokenBalanceInsufficient.selector,
                userBalance,
                LibConstants.MIN_BET_AMOUNT
            )
        );
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetSingle() public returns (uint boutId) {
        boutId = 100;

        BettingScenario memory scen = _getScenario1();

        // initialy no bouts
        assertEq(proxy.getTotalBouts(), 0, "no bouts at start");

        // place bet
        Wallet memory player = scen.players[0];
        _bet(player.addr, boutId, 1, scen.betAmounts[0]);

        // check total bouts
        assertEq(proxy.getTotalBouts(), 1, "total bouts");
        assertEq(proxy.getBoutIdByIndex(1), boutId, "bout id by index");

        // check bout basic state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(bout.state, BoutState.Created, "created");
        assertGt(bout.createTime, 0, "create time");
        assertEq(
            bout.expiryTime,
            bout.createTime + LibConstants.DEFAULT_BOUT_EXPIRATION_TIME,
            "expiry time"
        );
        assertEq(bout.numSupporters, 1, "no. of bettors");
        assertEq(bout.totalPot, scen.betAmounts[0], "total pot");
        assertEq(bout.winner, BoutFighter.Uninitialized, "bout winner");
        assertEq(bout.loser, BoutFighter.Uninitialized, "bout loser");

        assertEq(proxy.getBoutFighterPot(boutId, BoutFighter.FighterA), 0, "fighter A pot");
        assertEq(proxy.getBoutFighterPot(boutId, BoutFighter.FighterB), 0, "fighter B pot");
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

        // check player data
        assertEq(proxy.getBoutSupporter(boutId, 1), player.addr, "bettor address");
        assertEq(proxy.getBoutHiddenBet(boutId, player.addr), 1, "bettor hidden bet");
        assertEq(
            proxy.getBoutBetAmount(boutId, player.addr),
            scen.betAmounts[0],
            "bettor bet amount"
        );
        assertEq(proxy.getUserBoutsSupported(player.addr), 1, "user supported bouts");

        // check MEME balances
        assertEq(memeToken.balanceOf(player.addr), 0, "MEME balance");
        assertEq(memeToken.balanceOf(address(proxy)), bout.totalPot, "MEME balance");
    }

    function testBetMultiple() public returns (uint boutId) {
        boutId = 100;

        BettingScenario memory scen = _getScenario1();

        // place bets
        uint totalBetAmount = 0;
        for (uint i = 0; i < scen.players.length; i += 1) {
            Wallet memory player = scen.players[i];
            totalBetAmount += scen.betAmounts[i];
            _bet(player.addr, boutId, 1, scen.betAmounts[i]);
        }

        assertEq(totalBetAmount, scen.fighterAPot + scen.fighterBPot, "check total bet amount");

        // check total bouts
        assertEq(proxy.getTotalBouts(), 1, "still only 1 bout created");
        assertEq(proxy.getBoutIdByIndex(1), boutId, "bout id by index");

        // check bout basic state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(bout.numSupporters, 5, "no. of bettors");
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
            assertEq(proxy.getUserBoutsSupported(player.addr), 1, "user supported bouts");
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
            _bet(player1.addr, boutId, 1, LibConstants.MIN_BET_AMOUNT * i);
        }

        // check bout basic state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(bout.state, BoutState.Created, "created");
        assertEq(bout.numSupporters, 1, "no. of bettors");
        assertEq(bout.totalPot, LibConstants.MIN_BET_AMOUNT * 5, "total pot");

        // check bettor data
        assertEq(proxy.getBoutSupporter(boutId, 1), player1.addr, "bettor address");
        assertEq(proxy.getBoutHiddenBet(boutId, player1.addr), 1, "bettor hidden bet");
        assertEq(proxy.getBoutBetAmount(boutId, player1.addr), bout.totalPot, "bettor bet amount");
        assertEq(proxy.getUserBoutsSupported(player1.addr), 1, "user supported bouts");

        // check MEME balances
        assertEq(
            memeToken.balanceOf(player1.addr),
            LibConstants.MIN_BET_AMOUNT * 10,
            "MEME balance"
        );
        assertEq(memeToken.balanceOf(address(proxy)), bout.totalPot, "MEME balance");
    }

    function testBetEmitsEvent() public {
        uint boutId = 100;

        uint amount = LibConstants.MIN_BET_AMOUNT;

        vm.recordLogs();

        _bet(player1.addr, boutId, 1, amount);

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
        assertEq(bettor, player1.addr, "bettor incorrect");
    }

    // ------------------------------------------------------ //
    //
    // End bout
    //
    // ------------------------------------------------------ //

    function testEndBoutMustBeDoneByServer() public {
        uint boutId = testBetMultiple();

        BettingScenario memory scen = _getScenario1();

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

        BettingScenario memory scen = _getScenario1();

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

        BettingScenario memory scen = _getScenario1();

        vm.prank(server.addr);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidWinnerError.selector, boutId, BoutFighter.Uninitialized)
        );
        proxy.endBout(
            boutId,
            21,
            22,
            scen.fighterAPot,
            scen.fighterBPot,
            BoutFighter.Uninitialized,
            scen.revealValues
        );
    }

    function testEndBoutWithPotMismatch() public {
        uint boutId = testBetMultiple();

        BettingScenario memory scen = _getScenario1();

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

    function testEndBout() public returns (uint boutId) {
        boutId = testBetMultiple();

        BettingScenario memory scen = _getScenario1();

        uint preEndedBouts = proxy.getEndedBouts();

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
        assertEq(bout.loser, scen.loser, "loser");

        assertEq(bout.revealValues, scen.revealValues, "reveal values");

        assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterA), 21, "fighter A id");
        assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterB), 22, "fighter B id");
        assertEq(
            proxy.getBoutFighterPot(boutId, BoutFighter.FighterA),
            scen.fighterAPot,
            "fighter A pot"
        );
        assertEq(
            proxy.getBoutFighterPot(boutId, BoutFighter.FighterB),
            scen.fighterBPot,
            "fighter B pot"
        );
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

        // check global state
        assertEq(proxy.getEndedBouts(), preEndedBouts + 1, "ended bouts");
    }

    function testEndBoutCreatesBoutIfNeeded() public {
        uint boutId = 100; // doesn't exist

        BettingScenario memory scen = _getScenario1();

        uint preEndedBouts = proxy.getEndedBouts();

        uint8[] memory emptyRevealValues;

        vm.prank(server.addr);
        proxy.endBout(boutId, 21, 22, 0, 0, scen.winner, emptyRevealValues);

        // check total bouts
        assertEq(proxy.getTotalBouts(), 1, "total bouts");
        assertEq(proxy.getBoutIdByIndex(1), boutId, "bout id by index");

        // check bout state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(bout.state, BoutState.Ended, "state");
        assertGt(bout.endTime, 0, "end time");
        assertEq(bout.totalPot, 0, "total pot");
        assertEq(bout.revealValues, emptyRevealValues, "reveal values");
        assertEq(bout.winner, scen.winner, "winner");
        assertEq(bout.loser, scen.loser, "loser");

        assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterA), 21, "fighter A id");
        assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterB), 22, "fighter B id");
        assertEq(proxy.getBoutFighterPot(boutId, BoutFighter.FighterA), 0, "fighter A pot");
        assertEq(proxy.getBoutFighterPot(boutId, BoutFighter.FighterB), 0, "fighter B pot");
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

        // check global state
        assertEq(proxy.getEndedBouts(), preEndedBouts + 1, "ended bouts");
    }

    function testEndBoutEmitsEvent() public {
        uint boutId = testBetMultiple();

        BettingScenario memory scen = _getScenario1();

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

    // ------------------------------------------------------ //
    //
    // Test processing multiple bouts
    //
    // ------------------------------------------------------ //

    function testProcessMultipleBoutsInSequence() public returns (uint[] memory boutIds) {
        BettingScenario memory scen = _getScenario1();

        uint numBouts = 5;

        boutIds = new uint[](numBouts);

        for (uint i = 0; i < numBouts; i += 1) {
            boutIds[i] = 100 + i;

            for (uint j = 0; j < scen.players.length; j += 1) {
                _bet(scen.players[j].addr, boutIds[i], 1, scen.betAmounts[j]);
            }

            assertEq(proxy.getTotalBouts(), i + 1, "total bouts");
            assertEq(proxy.getEndedBouts(), i, "ended bouts before");

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

            assertEq(proxy.getEndedBouts(), i + 1, "ended bouts after");
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
            assertEq(bout.loser, scen.loser, "loser");

            assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterA), 21, "fighter A id");
            assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterB), 22, "fighter B id");
            assertEq(
                proxy.getBoutFighterPot(boutId, BoutFighter.FighterA),
                scen.fighterAPot,
                "fighter A pot"
            );
            assertEq(
                proxy.getBoutFighterPot(boutId, BoutFighter.FighterB),
                scen.fighterBPot,
                "fighter B pot"
            );

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
        BettingScenario memory scen = _getScenario1();

        uint numBouts = 5;

        boutIds = new uint[](numBouts);

        for (uint i = 0; i < numBouts; i += 1) {
            boutIds[i] = 100 + i;

            for (uint j = 0; j < scen.players.length; j += 1) {
                _bet(scen.players[j].addr, boutIds[i], 1, scen.betAmounts[j]);
            }
        }

        assertEq(proxy.getTotalBouts(), numBouts, "total bouts");
        assertEq(proxy.getEndedBouts(), 0, "ended bouts before");

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

        assertEq(proxy.getEndedBouts(), numBouts, "ended bouts after");

        for (uint i = 0; i < numBouts; i += 1) {
            uint boutId = boutIds[i];
            // check bout state
            BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
            assertEq(bout.state, BoutState.Ended, "state");
            assertGt(bout.endTime, 0, "end time");
            assertEq(bout.totalPot, scen.fighterAPot + scen.fighterBPot, "total pot");
            assertEq(bout.revealValues, scen.revealValues, "reveal values");
            assertEq(bout.winner, scen.winner, "winner");
            assertEq(bout.loser, scen.loser, "loser");

            assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterA), 21, "fighter A id");
            assertEq(proxy.getBoutFighterId(boutId, BoutFighter.FighterB), 22, "fighter B id");
            assertEq(
                proxy.getBoutFighterPot(boutId, BoutFighter.FighterA),
                scen.fighterAPot,
                "fighter A pot"
            );
            assertEq(
                proxy.getBoutFighterPot(boutId, BoutFighter.FighterB),
                scen.fighterBPot,
                "fighter B pot"
            );

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
    // Claim winnings - successfully completed bouts
    //
    // ------------------------------------------------------ //

    function testGetClaimableWinningsForSingleBout() public {
        testEndBout();

        BettingScenario memory scen = _getScenario1();

        // check claimable winnings
        for (uint i = 0; i < scen.players.length; i++) {
            Wallet memory player = scen.players[i];

            uint winnings = proxy.getClaimableWinnings(player.addr);

            assertEq(winnings, scen.expectedWinnings[i], "winnings");
        }
    }

    function testGetClaimableWinningsForMultipleBouts() public {
        uint[] memory boutIds = testProcessMultipleBoutsInParallel();

        BettingScenario memory scen = _getScenario1();

        // check claimable winnings
        for (uint i = 1; i < 2; i++) {
            Wallet memory player = scen.players[i];

            uint winnings = proxy.getClaimableWinnings(player.addr);

            assertEq(winnings, scen.expectedWinnings[i] * boutIds.length, "winnings");
        }
    }

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

        BettingScenario memory scen = _getScenario1();

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
            (v.total, v.selfAmount, v.won) = proxy.getBoutWinnings(boutId, player.addr);

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

        BettingScenario memory scen = _getScenario1();

        ClaimWinningsLoopValues[] memory v = new ClaimWinningsLoopValues[](boutIds.length);
        Wallet memory player = scen.players[1]; // 2nd and 4th players are winners
        assertEq(uint(scen.betTargets[1]), uint(scen.winner));

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
            (v[i].total, v[i].selfAmount, v[i].won) = proxy.getBoutWinnings(boutId, player.addr);

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

        BettingScenario memory scen = _getScenario1();

        ClaimWinningsLoopValues[] memory v = new ClaimWinningsLoopValues[](boutIds.length);
        Wallet memory player = scen.players[1]; // 2nd player is a winner
        assertEq(uint(scen.betTargets[1]), uint(scen.winner));

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
            (v[i].total, v[i].selfAmount, v[i].won) = proxy.getBoutWinnings(boutId, player.addr);

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

    function testEndBoutWhenExpired() public returns (uint boutId) {
        boutId = testBetMultiple();

        uint expiryTime = proxy.getBoutNonMappingInfo(boutId).expiryTime;

        // move to past expiry
        vm.warp(expiryTime);

        BettingScenario memory scen = _getScenario1();

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

    // ------------------------------------------------------ //
    //
    // Private/internal methods
    //
    // ------------------------------------------------------ //

    function _bet(address bettor, uint boutId, uint8 br, uint amount) internal {
        // mint tokens
        proxy._testMintMeme(bettor, amount);

        // do signature
        bytes32 digest = proxy.calculateBetSignature(
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
        BoutFighter[] betTargets;
        uint fighterAPot;
        uint fighterBPot;
        uint8[] revealValues;
        BoutFighter winner;
        BoutFighter loser;
        uint[] expectedWinnings;
    }

    function _getScenario1() internal view returns (BettingScenario memory scen) {
        scen.players = new Wallet[](5);
        scen.players[0] = player1;
        scen.players[1] = player2;
        scen.players[2] = player3;
        scen.players[3] = player4;
        scen.players[4] = player5;

        scen.betAmounts = new uint[](5);
        uint winningPot;
        uint losingPot;
        for (uint i = 0; i < 5; i++) {
            scen.betAmounts[i] = LibConstants.MIN_BET_AMOUNT * (i + 1);
            if (i % 2 == 0) {
                losingPot += scen.betAmounts[i];
            } else {
                winningPot += scen.betAmounts[i];
            }
        }

        require(winningPot == LibConstants.MIN_BET_AMOUNT * 6, "winning pot");
        require(losingPot == LibConstants.MIN_BET_AMOUNT * 9, "losing pot");

        /*
        5 players, odd ones will bet for fighterA, even for fighterB

        Thus, 2 bytes with bit pattern:

        01 00 01 00, 01 00 00 00
        */

        scen.betTargets = new BoutFighter[](5);
        scen.betTargets[0] = BoutFighter.FighterA;
        scen.betTargets[1] = BoutFighter.FighterB;
        scen.betTargets[2] = BoutFighter.FighterA;
        scen.betTargets[3] = BoutFighter.FighterB;
        scen.betTargets[4] = BoutFighter.FighterA;

        scen.revealValues = new uint8[](2);
        scen.revealValues[0] = 68; // 01000100
        scen.revealValues[1] = 64; // 01000000

        scen.winner = BoutFighter.FighterB;
        scen.loser = BoutFighter.FighterA;

        scen.fighterAPot = losingPot;
        scen.fighterBPot = winningPot;

        scen.expectedWinnings = new uint[](5);
        scen.expectedWinnings[0] = 0;
        scen.expectedWinnings[1] =
            scen.betAmounts[1] +
            ((((scen.betAmounts[1] * 1000 ether) / winningPot) * losingPot) / 1000 ether);
        scen.expectedWinnings[2] = 0;
        scen.expectedWinnings[3] =
            scen.betAmounts[3] +
            ((((scen.betAmounts[3] * 1000 ether) / winningPot) * losingPot) / 1000 ether);
        scen.expectedWinnings[4] = 0;
    }
}
