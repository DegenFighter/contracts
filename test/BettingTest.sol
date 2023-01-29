// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import "../src/Errors.sol";
import { BoutNonMappingInfo, BoutFighter, BoutState } from "../src/Objects.sol";
import { Wallet, TestBaseContract } from "./utils/TestBaseContract.sol";
import { LibConstants, LibTokenIds } from "../src/libs/LibConstants.sol";

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

        // state: Ended
        proxy._testSetBoutState(boutId, BoutState.Ended);
        vm.expectRevert(abi.encodePacked(BoutInWrongStateError.selector, uint256(1), uint256(BoutState.Ended)));
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, 1, "0x", "0x");

        // state: Cancelled
        proxy._testSetBoutState(boutId, BoutState.Cancelled);
        vm.expectRevert(abi.encodePacked(BoutInWrongStateError.selector, uint256(1), uint256(BoutState.Cancelled)));
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, 1, "0x", "0x");
    }

    function testBetWithBadSigner() public {
        uint boutId = 100;

        // do signature
        address signer = vm.addr(123);
        bytes32 digest = proxy.calculateBetSignature(signer, account0, 1, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(123, digest);

        vm.expectRevert(SignerMustBeServerError.selector);
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetWithExpiredDeadline() public {
        uint boutId = 100;

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, 1, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp - 1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(SignatureExpiredError.selector);
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp - 1, v, r, s);
    }

    function testBetWithInsufficientBetAmount() public {
        uint boutId = 100;

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, 1, 1, LibConstants.MIN_BET_AMOUNT - 1, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(abi.encodeWithSelector(MinimumBetAmountError.selector, 1, address(this), LibConstants.MIN_BET_AMOUNT - 1));
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT - 1, block.timestamp + 1000, v, r, s);
    }

    function testBetWithInvalidBetTarget(uint8 br) public {
        vm.assume(br < 1 || br > 3); // Invalid bet target

        uint boutId = 100;

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, 1, br, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(abi.encodeWithSelector(InvalidBetTargetError.selector, 1, address(this), br));
        proxy.bet(boutId, br, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetWithInsufficentTokens() public {
        uint boutId = 100;

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, 1, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        uint256 userBalance = proxy.tokenBalanceOf(LibTokenIds.TOKEN_MEME, address(this));

        vm.expectRevert(abi.encodeWithSelector(TokenBalanceInsufficient.selector, userBalance, LibConstants.MIN_BET_AMOUNT));
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetSetsUpBoutState() public returns (uint boutId) {
        boutId = 100;

        (Wallet[] memory players, uint[] memory betAmounts, , , , , ) = _getScenario1();

        // initialy no bouts
        assertEq(proxy.totalBouts(), 0, "no bouts at start");

        // place bet
        Wallet memory player = players[0];
        _bet(player.addr, boutId, 1, betAmounts[0]);

        // check total bouts
        assertEq(proxy.totalBouts(), 1, "total bouts");
        assertEq(proxy.getBoutIdByIndex(1), boutId, "bout id by index");

        // check bout basic state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(uint(bout.state), uint(BoutState.Created), "created");
        assertEq(bout.numSupporters, 1, "no. of bettors");
        assertEq(bout.totalPot, LibConstants.MIN_BET_AMOUNT * 15, "total pot");
        assertEq(bout.state, BoutState.Created, "bout state");
        assertEq(bout.winner, BoutFighter.Uninitialized, "bout winner");
        assertEq(bout.loser, BoutFighter.Uninitialized, "bout loser");
        assertEq(bout.fighterPots[BoutFighter.FighterA], 0, "fighter A pot");
        assertEq(bout.fighterPots[BoutFighter.FighterB], 0, "fighter B pot");
        assertEq(bout.fighterPotBalances[BoutFighter.FighterA], 0, "fighter A pot balance");
        assertEq(bout.fighterPotBalances[BoutFighter.FighterB], 0, "fighter B pot balance");

        // check player data
        assertEq(proxy.getBoutSupporter(boutId, i), player.addr, "bettor address");
        assertEq(proxy.getBoutHiddenBet(boutId, player.addr), 1, "bettor hidden bet");
        assertEq(proxy.getBoutBetAmount(boutId, player.addr), betAmounts[i - 1], "bettor bet amount");
        assertEq(proxy.getUserBoutsSupported(player.addr), 1, "user supported bouts");

        // check MEME balances
        assertEq(memeToken.balanceOf(player.addr), 0, "MEME balance");
        assertEq(memeToken.balanceOf(address(proxy)), bout.totalPot, "MEME balance");
    }

    function testBetMultipleSucceeds() public returns (uint boutId) {
        boutId = 100;

        (Wallet[] memory players, uint[] memory betAmounts, , , , , ) = _getScenario1();

        // place bets
        for (uint i = 0; i < players.length; i += 1) {
            Wallet memory player = players[i];
            _bet(player.addr, boutId, 1, betAmounts[i]);
        }

        // check total bouts
        assertEq(proxy.totalBouts(), 1, "still only 1 bout created");
        assertEq(proxy.getBoutIdByIndex(1), boutId, "bout id by index");

        // check bout basic state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(bout.numSupporters, 5, "no. of bettors");
        assertEq(bout.totalPot, LibConstants.MIN_BET_AMOUNT * 15, "total pot");

        // check bettor data
        for (uint i = 1; i <= players.length; i += 1) {
            Wallet memory player = players[i - 1];

            assertEq(proxy.getBoutSupporter(boutId, i), player.addr, "bettor address");
            assertEq(proxy.getBoutHiddenBet(boutId, player.addr), 1, "bettor hidden bet");
            assertEq(proxy.getBoutBetAmount(boutId, player.addr), betAmounts[i - 1], "bettor bet amount");
            assertEq(proxy.getUserBoutsSupported(player.addr), 1, "user supported bouts");
        }

        // check MEME balances
        for (uint i = 0; i < players.length; i += 1) {
            Wallet memory player = players[i];
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
        assertEq(uint(bout.state), uint(BoutState.Created), "created");
        assertEq(bout.numSupporters, 1, "no. of bettors");
        assertEq(bout.totalPot, LibConstants.MIN_BET_AMOUNT * 5, "total pot");

        // check bettor data
        assertEq(proxy.getBoutSupporter(boutId, 1), player1.addr, "bettor address");
        assertEq(proxy.getBoutHiddenBet(boutId, player1.addr), 1, "bettor hidden bet");
        assertEq(proxy.getBoutBetAmount(boutId, player1.addr), bout.totalPot, "bettor bet amount");
        assertEq(proxy.getUserBoutsSupported(player1.addr), boutId, "user supported bouts");

        // check MEME balances
        assertEq(memeToken.balanceOf(player1.addr), LibConstants.MIN_BET_AMOUNT * 10, "MEME balance");
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
        assertEq(entries[2].topics[0], keccak256("BetPlaced(uint256,address)"), "Invalid event signature");
        (uint eBoutId, address bettor) = abi.decode(entries[2].data, (uint256, address));
        assertEq(eBoutId, boutId, "boutId incorrect");
        assertEq(bettor, player1.addr, "bettor incorrect");
    }

    // ------------------------------------------------------ //
    //
    // Reveal bets
    //
    // ------------------------------------------------------ //

    function testRevealBetsMustBeDoneByServer() public {
        // create bout and place bets
        uint boutId = testBetMultipleSucceeds();

        address dummyServer = vm.addr(123);

        uint8[] memory rPacked = new uint8[](0);

        vm.prank(dummyServer);
        vm.expectRevert(CallerMustBeServerError.selector);
        proxy.revealBets(boutId, 0, rPacked);

        proxy.setAddress(LibConstants.SERVER_ADDRESS, dummyServer);

        vm.prank(dummyServer);
        proxy.revealBets(boutId, 0, rPacked);
    }

    function testRevealBetsInWrongState() public {
        // create bout and place bets
        uint boutId = testBetMultipleSucceeds();

        uint8[] memory rPacked = new uint8[](0);

        // state: Unknown
        proxy._testSetBoutState(boutId, BoutState.Unknown);
        vm.prank(server.addr);
        vm.expectRevert(abi.encodeWithSelector(BoutInWrongStateError.selector, 1, BoutState.Unknown));
        proxy.revealBets(boutId, 0, rPacked);

        // state: Ended
        proxy._testSetBoutState(boutId, BoutState.Ended);
        vm.prank(server.addr);
        vm.expectRevert(abi.encodeWithSelector(BoutInWrongStateError.selector, 1, BoutState.Ended));
        proxy.revealBets(boutId, 0, rPacked);
    }

    function testRevealBetsEmitsEvent() public {
        // create bout and place bets
        uint boutId = testBetMultipleSucceeds();

        uint8[] memory rPacked = new uint8[](2);

        vm.recordLogs();

        vm.prank(server.addr);
        proxy.revealBets(boutId, 3, rPacked);

        // check logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1, "Invalid event count");
        assertEq(entries[0].topics[0], keccak256("BetsRevealed(uint256,uint256)"));
        (uint eBoutId, uint count) = abi.decode(entries[0].data, (uint, uint));
        assertEq(eBoutId, boutId, "boutId incorrect");
        assertEq(count, 3, "count incorrect");
    }

    function testRevealBets() public returns (uint boutId) {
        // create bout and place bets
        boutId = testBetMultipleSucceeds();

        (Wallet[] memory players, uint[] memory betAmounts, BoutFighter[] memory betTargets, uint8[] memory rPacked, , , ) = _getScenario1();

        vm.prank(server.addr);
        proxy.revealBets(boutId, 5, rPacked);

        // num of revealed bets
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(uint(bout.state), uint(BoutState.BetsRevealed), "state");
        assertGt(bout.revealTime, 0, "reveal time");
        assertEq(bout.numRevealedBets, 5, "num revealed bets (1st call)");

        // now let's check the revealed bets
        for (uint i = 0; i < players.length; i++) {
            assertEq(uint(proxy.getBoutRevealedBet(boutId, players[i].addr)), uint(betTargets[i]), "revealed bet");
        }

        // check the fighter pots
        uint aPot = betAmounts[0] + betAmounts[2] + betAmounts[4];
        assertEq(proxy.getBoutFighterPot(boutId, BoutFighter.FighterA), aPot, "fighter A pot");
        assertEq(proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterA), aPot, "fighter A pot balance");

        uint bPot = betAmounts[1] + betAmounts[3];
        assertEq(proxy.getBoutFighterPot(boutId, BoutFighter.FighterB), bPot, "fighter B pot");
        assertEq(proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterB), bPot, "fighter B pot balance");
    }

    function testRevealBetsWithMultipleCalls() public {
        // create bout and place bets
        uint boutId = testBetMultipleSucceeds();

        (Wallet[] memory players, uint[] memory betAmounts, BoutFighter[] memory betTargets, uint8[] memory rPacked, , , ) = _getScenario1();

        uint8[] memory rPacked1 = new uint8[](1);
        rPacked1[0] = rPacked[0];
        uint8[] memory rPacked2 = new uint8[](1);
        rPacked2[0] = rPacked[1];

        // first call
        vm.prank(server.addr);
        proxy.revealBets(boutId, 4, rPacked1);

        assertEq(proxy.getBoutNonMappingInfo(boutId).numRevealedBets, 4, "num revealed bets (1st call)");
        for (uint i = 0; i < 4; i++) {
            assertEq(uint(proxy.getBoutRevealedBet(boutId, players[i].addr)), uint(betTargets[i]), "revealed bet");
        }
        assertEq(uint(proxy.getBoutRevealedBet(boutId, player5.addr)), uint(BoutFighter.Unknown), "revealed bet 5");

        // 2nd call
        vm.prank(server.addr);
        proxy.revealBets(boutId, 1, rPacked2);

        assertEq(proxy.getBoutNonMappingInfo(boutId).numRevealedBets, 5, "num revealed bets (2nd call)");
        assertEq(uint(proxy.getBoutRevealedBet(boutId, player5.addr)), uint(BoutFighter.FighterA), "revealed bet 5");

        // check the fighter pots
        uint aPot = betAmounts[0] + betAmounts[2] + betAmounts[4];
        assertEq(proxy.getBoutFighterPot(boutId, BoutFighter.FighterA), aPot, "fighter A pot");

        uint bPot = betAmounts[1] + betAmounts[3];
        assertEq(proxy.getBoutFighterPot(boutId, BoutFighter.FighterB), bPot, "fighter B pot");
    }

    function testRevealBetsWithBadRValues() public {
        // create bout and place bets
        uint boutId = testBetMultipleSucceeds();

        /*
        Since B+R = 1, we'll use 2 and 3 here to cause an underflow. 
        The bet value should default to 0.

        11 10 11 10, 11 00 00 00
        */
        uint8[] memory rPacked = new uint8[](2);
        rPacked[0] = 238; // 11 10 11 10
        rPacked[1] = 192; // 11 00 00 00

        vm.prank(server.addr);
        proxy.revealBets(boutId, 5, rPacked);

        // now let's check the revealed bets
        assertEq(uint(proxy.getBoutRevealedBet(boutId, player1.addr)), uint(BoutFighter.FighterA), "revealed bet 1");
        assertEq(uint(proxy.getBoutRevealedBet(boutId, player2.addr)), uint(BoutFighter.FighterA), "revealed bet 2");
        assertEq(uint(proxy.getBoutRevealedBet(boutId, player3.addr)), uint(BoutFighter.FighterA), "revealed bet 3");
        assertEq(uint(proxy.getBoutRevealedBet(boutId, player4.addr)), uint(BoutFighter.FighterA), "revealed bet 4");
        assertEq(uint(proxy.getBoutRevealedBet(boutId, player5.addr)), uint(BoutFighter.FighterA), "revealed bet 5");

        // check the fighter pots
        assertEq(proxy.getBoutFighterPot(boutId, BoutFighter.FighterA), proxy.getBoutNonMappingInfo(boutId).totalPot, "fighter A pot");
        assertEq(proxy.getBoutFighterPot(boutId, BoutFighter.FighterB), 0, "fighter B pot");
    }

    function testRevealBetsWhenAlreadyFullyRevealed() public {
        // create bout and place bets
        uint boutId = testBetMultipleSucceeds();

        vm.startPrank(server.addr);

        uint8[] memory rPacked = new uint8[](2);
        proxy.revealBets(boutId, 5, rPacked);

        // doing again is ok
        proxy.revealBets(boutId, 1, rPacked);

        assertEq(proxy.getBoutNonMappingInfo(boutId).numRevealedBets, 5, "num revealed bets");

        vm.stopPrank();
    }

    // ------------------------------------------------------ //
    //
    // End bout
    //
    // ------------------------------------------------------ //

    function testEndBoutMustBeDoneByServer() public {
        // create bout, place bets, reveal bets
        uint boutId = testRevealBets();

        address dummyServer = vm.addr(123);

        vm.prank(dummyServer);
        vm.expectRevert(CallerMustBeServerError.selector);
        proxy.endBout(boutId, BoutFighter.FighterA);

        proxy.setAddress(LibConstants.SERVER_ADDRESS, dummyServer);

        vm.prank(dummyServer);
        proxy.endBout(boutId, BoutFighter.FighterA);
    }

    function testEndBoutEmitsEvent() public {
        // create bout, place bets, reveal bets
        uint boutId = testRevealBets();

        vm.recordLogs();

        vm.prank(server.addr);
        proxy.endBout(boutId, BoutFighter.FighterA);

        // check logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1, "Invalid event count");
        assertEq(entries[0].topics[0], keccak256("BoutEnded(uint256)"));
        uint eBoutId = abi.decode(entries[0].data, (uint));
        assertEq(eBoutId, boutId, "boutId incorrect");
    }

    function testEndBoutWithInvalidState() public {
        // create bout, place bets, reveal bets
        uint boutId = testRevealBets();

        vm.startPrank(server.addr);

        // state: Unknown
        proxy._testSetBoutState(boutId, BoutState.Unknown);
        vm.expectRevert(abi.encodeWithSelector(BoutInWrongStateError.selector, 1, BoutState.Unknown));
        proxy.endBout(boutId, BoutFighter.FighterA);

        // state: Created
        proxy._testSetBoutState(boutId, BoutState.Created);
        vm.expectRevert(abi.encodeWithSelector(BoutInWrongStateError.selector, 1, BoutState.Created));
        proxy.endBout(boutId, BoutFighter.FighterA);

        // state: Ended
        proxy._testSetBoutState(boutId, BoutState.Ended);
        vm.expectRevert(abi.encodeWithSelector(BoutInWrongStateError.selector, 1, BoutState.Ended));
        proxy.endBout(boutId, BoutFighter.FighterA);

        vm.stopPrank();
    }

    function testEndBoutWithInvalidWinner() public {
        // create bout, place bets, reveal bets
        uint boutId = testRevealBets();

        vm.prank(server.addr);
        vm.expectRevert(abi.encodeWithSelector(InvalidWinnerError.selector, 1, BoutFighter.Unknown));
        proxy.endBout(boutId, BoutFighter.Unknown);
    }

    function testEndBout() public returns (uint boutId) {
        // create bout, place bets, reveal bets
        boutId = testRevealBets();

        (, , , , BoutFighter winner, BoutFighter loser, ) = _getScenario1();

        vm.prank(server.addr);
        proxy.endBout(boutId, winner);

        // check the state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(uint(bout.state), uint(BoutState.Ended), "state");
        assertGt(bout.endTime, 0, "end time");
        assertEq(uint(bout.winner), uint(winner), "winner");
        assertEq(uint(bout.loser), uint(loser), "loser");

        // check global state
        assertEq(proxy.getEndedBouts(), boutId, "ended bouts");
    }

    // ------------------------------------------------------ //
    //
    // Test processing multiple bouts
    //
    // ------------------------------------------------------ //

    function testCompleteMultipleBouts() internal returns (uint[] memory boutIds) {
        (
            Wallet[] memory players,
            uint[] memory betAmounts,
            BoutFighter[] memory betTargets,
            uint8[] memory rPacked,
            BoutFighter winner,
            BoutFighter loser,
            uint[] memory expectedWinnings
        ) = _getScenario1();

        boutIds = new uint[](5);

        // create bout, place bets, reveal bets, end bout
        for (uint i = 0; i < 5; i += 1) {
            vm.prank(server.addr);
            proxy.createBout(fighterAId, fighterBId);

            boutIds[i] = proxy.getTotalBouts();

            for (uint j = 0; j < players.length; j += 1) {
                _bet(players[j].addr, boutIds[i], 1, betAmounts[j]);
            }

            vm.startPrank(server.addr);
            proxy.revealBets(boutIds[i], 5, rPacked);
            proxy.endBout(boutIds[i], winner);
            vm.stopPrank();
        }

        // check total bouts
        assertEq(proxy.getTotalBouts(), boutIds.length, "total bouts");
    }

    // ------------------------------------------------------ //
    //
    // Claim winnings
    //
    // ------------------------------------------------------ //

    function testGetClaimableWinningsForSingleBout() public {
        // create bout, place bets, reveal bets, end bout
        testEndBout();

        (Wallet[] memory players, , , , , , uint[] memory expectedWinnings) = _getScenario1();

        // check claimable winnings
        for (uint i = 0; i < players.length; i++) {
            Wallet memory player = players[i];

            uint winnings = proxy.getClaimableWinnings(player.addr);

            assertEq(winnings, expectedWinnings[i], "winnings");
        }
    }

    function testGetClaimableWinningsForMultipleBouts() public {
        uint[] memory boutIds = testCompleteMultipleBouts();

        (Wallet[] memory players, , , , , , uint[] memory expectedWinnings) = _getScenario1();

        // check claimable winnings
        for (uint i = 0; i < players.length; i++) {
            Wallet memory player = players[i];

            uint winnings = proxy.getClaimableWinnings(player.addr);

            assertEq(winnings, expectedWinnings[i] * boutIds.length, "winnings");
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
        // create bout, place bets, reveal bets, end bout
        uint boutId = testEndBout();

        (
            Wallet[] memory players,
            uint[] memory betAmounts,
            BoutFighter[] memory betTargets,
            ,
            BoutFighter winner,
            BoutFighter loser,
            uint[] memory expectedWinnings
        ) = _getScenario1();

        ClaimWinningsLoopValues memory v;
        Wallet memory player;

        // check claimable winnings
        for (uint i = 0; i < players.length; i++) {
            player = players[i];

            // get fighter pot balances
            v.winnerPotPrevBalance = proxy.getBoutFighterPotBalance(boutId, winner);
            v.loserPotPrevBalance = proxy.getBoutFighterPotBalance(boutId, loser);

            // get meme token balance of proxy
            v.proxyMemeTokenBalance = memeToken.balanceOf(proxyAddress);

            // get bout winnings for this player
            (v.total, v.selfAmount, v.won) = proxy.getBoutWinnings(boutId, player.addr);

            // make claim
            proxy.claimWinnings(player.addr, 1);

            // check fighter pot balances
            v.winnerPotPostBalance = proxy.getBoutFighterPotBalance(boutId, winner);
            v.loserPotPostBalance = proxy.getBoutFighterPotBalance(boutId, loser);
            if (betTargets[i] == winner) {
                assertEq(v.winnerPotPostBalance, v.winnerPotPrevBalance - v.selfAmount);
                assertEq(v.loserPotPostBalance, v.loserPotPrevBalance - v.won);
            } else {
                assertEq(v.winnerPotPostBalance, v.winnerPotPrevBalance);
                assertEq(v.loserPotPostBalance, v.loserPotPrevBalance);
            }

            // check bout winnings claimed status
            assertEq(proxy.getBoutWinningsClaimed(boutId, player.addr), true, "bout winnings claimed");

            // check that tokens were transferred
            assertEq(memeToken.balanceOf(player.addr), v.total, "total winnings");
            assertEq(memeToken.balanceOf(proxyAddress), v.proxyMemeTokenBalance - v.total, "proxy meme token balance");

            // check that there no more winnings to claim for this player
            assertEq(proxy.getClaimableWinnings(player.addr), 0, "all winnings claimed");
        }
    }

    function testClaimWinningsForMultipleBouts() public {
        // create bout, place bets, reveal bets, end bout
        uint[] memory boutIds = testCompleteMultipleBouts();

        (
            Wallet[] memory players,
            uint[] memory betAmounts,
            BoutFighter[] memory betTargets,
            ,
            BoutFighter winner,
            BoutFighter loser,
            uint[] memory expectedWinnings
        ) = _getScenario1();

        ClaimWinningsLoopValues[] memory v = new ClaimWinningsLoopValues[](boutIds.length);
        Wallet memory player = players[1]; // 2nd and 4th players are winners
        assertEq(uint(betTargets[1]), uint(winner));

        uint winningsClaimed = 0;
        uint totalWinnings = proxy.getClaimableWinnings(player.addr);
        uint proxyMemeTokenBalance = memeToken.balanceOf(proxyAddress);

        // get pre-values
        for (uint i = 0; i < boutIds.length; i++) {
            uint boutId = boutIds[i];

            // get fighter pot balances
            v[i].winnerPotPrevBalance = proxy.getBoutFighterPotBalance(boutId, winner);
            v[i].loserPotPrevBalance = proxy.getBoutFighterPotBalance(boutId, loser);

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
            v[i].winnerPotPostBalance = proxy.getBoutFighterPotBalance(boutId, winner);
            v[i].loserPotPostBalance = proxy.getBoutFighterPotBalance(boutId, loser);
            assertEq(v[i].winnerPotPostBalance, v[i].winnerPotPrevBalance - v[i].selfAmount);
            assertEq(v[i].loserPotPostBalance, v[i].loserPotPrevBalance - v[i].won);

            // check bout winnings claimed status
            assertEq(proxy.getBoutWinningsClaimed(boutId, player.addr), true, "bout winnings claimed");
        }

        // check that tokens were transferred
        assertEq(memeToken.balanceOf(player.addr), winningsClaimed, "total winnings");
        assertEq(memeToken.balanceOf(proxyAddress), proxyMemeTokenBalance - winningsClaimed, "proxy meme token balance");

        // check that there no more winnings to claim for this player
        assertEq(proxy.getClaimableWinnings(player.addr), 0, "all winnings claimed");
    }

    function testClaimWinningsForMultipleBoutsSubset() public {
        // create bout, place bets, reveal bets, end bout
        uint[] memory boutIds = testCompleteMultipleBouts();

        (
            Wallet[] memory players,
            uint[] memory betAmounts,
            BoutFighter[] memory betTargets,
            ,
            BoutFighter winner,
            BoutFighter loser,
            uint[] memory expectedWinnings
        ) = _getScenario1();

        ClaimWinningsLoopValues[] memory v = new ClaimWinningsLoopValues[](boutIds.length);
        Wallet memory player = players[1]; // 2nd and 4th players are winners
        assertEq(uint(betTargets[1]), uint(winner));

        uint winningsClaimed = 0;
        uint totalWinnings = proxy.getClaimableWinnings(player.addr);
        uint proxyMemeTokenBalance = memeToken.balanceOf(proxyAddress);

        uint MAX_BOUTS = 2;

        // get pre-values
        for (uint i = 0; i < MAX_BOUTS; i++) {
            uint boutId = boutIds[i];

            // get fighter pot balances
            v[i].winnerPotPrevBalance = proxy.getBoutFighterPotBalance(boutId, winner);
            v[i].loserPotPrevBalance = proxy.getBoutFighterPotBalance(boutId, loser);

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
            v[i].winnerPotPostBalance = proxy.getBoutFighterPotBalance(boutId, winner);
            v[i].loserPotPostBalance = proxy.getBoutFighterPotBalance(boutId, loser);
            assertEq(v[i].winnerPotPostBalance, v[i].winnerPotPrevBalance - v[i].selfAmount);
            assertEq(v[i].loserPotPostBalance, v[i].loserPotPrevBalance - v[i].won);

            // check bout winnings claimed status
            assertEq(proxy.getBoutWinningsClaimed(boutId, player.addr), true, "bout winnings claimed");
        }

        // check that tokens were transferred
        assertEq(memeToken.balanceOf(player.addr), winningsClaimed, "total winnings");
        assertEq(memeToken.balanceOf(proxyAddress), proxyMemeTokenBalance - winningsClaimed, "proxy meme token balance");

        // check that there are still winnings to claim for this player
        assertEq(proxy.getClaimableWinnings(player.addr), totalWinnings - winningsClaimed, "some winnings claimed");
    }

    // ------------------------------------------------------ //
    //
    // Edge cases
    //
    // ------------------------------------------------------ //

    // function testWhenAllBetsAreOnOneFighter() public {
    //     // TODO...
    // }

    // ------------------------------------------------------ //
    //
    // Private/internal methods
    //
    // ------------------------------------------------------ //

    function _bet(address bettor, uint boutId, uint8 br, uint amount) internal {
        // mint tokens
        proxy._testMintMeme(bettor, amount);

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, bettor, boutId, br, amount, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.prank(bettor);
        proxy.bet(boutId, br, amount, block.timestamp + 1000, v, r, s);
    }

    function _getScenario1()
        internal
        view
        returns (
            Wallet[] memory players,
            uint[] memory betAmounts,
            BoutFighter[] memory betTargets,
            uint8[] memory rPacked,
            BoutFighter winner,
            BoutFighter loser,
            uint[] memory expectedWinnings
        )
    {
        players = new Wallet[](5);
        players[0] = player1;
        players[1] = player2;
        players[2] = player3;
        players[3] = player4;
        players[4] = player5;

        betAmounts = new uint[](5);
        uint winningPot;
        uint losingPot;
        for (uint i = 0; i < 5; i++) {
            betAmounts[i] = LibConstants.MIN_BET_AMOUNT * (i + 1);
            if (i % 2 == 0) {
                losingPot += betAmounts[i];
            } else {
                winningPot += betAmounts[i];
            }
        }

        require(winningPot == LibConstants.MIN_BET_AMOUNT * 6, "winning pot");
        require(losingPot == LibConstants.MIN_BET_AMOUNT * 9, "losing pot");

        /*
        5 players, odd ones will bet for fighterA, even for fighterB

        Thus, 2 bytes with bit pattern:

        01 00 01 00, 01 00 00 00
        */

        betTargets = new BoutFighter[](5);
        betTargets[0] = BoutFighter.FighterA;
        betTargets[1] = BoutFighter.FighterB;
        betTargets[2] = BoutFighter.FighterA;
        betTargets[3] = BoutFighter.FighterB;
        betTargets[4] = BoutFighter.FighterA;

        rPacked = new uint8[](2);
        rPacked[0] = 68; // 01000100
        rPacked[1] = 64; // 01000000

        winner = BoutFighter.FighterB;
        loser = BoutFighter.FighterA;

        expectedWinnings = new uint[](5);
        expectedWinnings[0] = 0;
        expectedWinnings[1] = betAmounts[1] + ((((betAmounts[1] * 1000 ether) / winningPot) * losingPot) / 1000 ether);
        expectedWinnings[2] = 0;
        expectedWinnings[3] = betAmounts[3] + ((((betAmounts[3] * 1000 ether) / winningPot) * losingPot) / 1000 ether);
        expectedWinnings[4] = 0;
    }
}
