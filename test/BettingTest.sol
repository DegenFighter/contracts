// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import "../src/Errors.sol";
import { BoutNonMappingInfo, BoutFighter, BoutState } from "../src/Objects.sol";
import { Wallet, TestBaseContract } from "./utils/TestBaseContract.sol";
import { LibConstants } from "../src/libs/LibConstants.sol";

contract BettingTest is TestBaseContract {
    uint fighterAId = 1;
    uint fighterBId = 2;

    function setUp() public override {
        super.setUp();
    }

    // ------------------------------------------------------ //
    //
    // Create bout
    //
    // ------------------------------------------------------ //

    function testCreateBoutMustBeDoneByServer() public {
        address dummyServer = vm.addr(123);

        vm.prank(dummyServer);
        vm.expectRevert(CallerMustBeServerError.selector);
        proxy.createBout(fighterAId, fighterBId);

        proxy.setAddress(LibConstants.SERVER_ADDRESS, dummyServer);

        vm.prank(dummyServer);
        proxy.createBout(fighterAId, fighterBId);
    }

    function testCreateBout() public returns (uint boutNum) {
        vm.prank(server.addr);
        proxy.createBout(fighterAId, fighterBId);

        // check basic bout info
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(proxy.getTotalBouts());
        assertEq(bout.id, 1, "bout id");
        assertEq(uint(bout.state), uint(BoutState.Created), "created");
        assertEq(uint(bout.winner), uint(BoutFighter.Unknown), "winner not set");
        assertEq(uint(bout.loser), uint(BoutFighter.Unknown), "loser not set");

        // check bout fighters
        assertEq(proxy.getBoutFighterId(1, BoutFighter.FighterA), fighterAId, "fighterAId");
        assertEq(proxy.getBoutFighterId(1, BoutFighter.FighterB), fighterBId, "fighterBId");

        assertEq(proxy.getTotalBouts(), 1, "bout total");

        // for use in tests which call this test
        boutNum = bout.id;
    }

    function testCreateBoutEmitsEvent() public {
        assertEq(proxy.getTotalBouts(), 0, "no bouts");

        vm.recordLogs();

        // create
        vm.prank(server.addr);
        proxy.createBout(fighterAId, fighterBId);

        // check logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1, "Invalid event count");
        assertEq(entries[0].topics[0], keccak256("BoutCreated(uint256)"));
        uint boutNum = abi.decode(entries[0].data, (uint256));
        assertEq(boutNum, 1, "boutNum incorrect");
    }

    // ------------------------------------------------------ //
    //
    // Place bet
    //
    // ------------------------------------------------------ //

    function testBetWithInvalidBoutState() public {
        // create bout
        uint boutNum = testCreateBout();

        // state: Unknown
        proxy._testSetBoutState(boutNum, BoutState.Unknown);
        vm.expectRevert(abi.encodePacked(BoutInWrongStateError.selector, uint256(1), uint256(BoutState.Unknown)));
        proxy.bet(boutNum, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, 1, "0x", "0x");

        // state: BetsRevealed
        proxy._testSetBoutState(boutNum, BoutState.BetsRevealed);
        vm.expectRevert(abi.encodePacked(BoutInWrongStateError.selector, uint256(1), uint256(BoutState.BetsRevealed)));
        proxy.bet(boutNum, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, 1, "0x", "0x");

        // state: Ended
        proxy._testSetBoutState(boutNum, BoutState.Ended);
        vm.expectRevert(abi.encodePacked(BoutInWrongStateError.selector, uint256(1), uint256(BoutState.Ended)));
        proxy.bet(boutNum, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, 1, "0x", "0x");
    }

    function testBetWithBadSigner() public {
        // create bout
        uint boutNum = testCreateBout();

        // do signature
        address signer = vm.addr(123);
        bytes32 digest = proxy.calculateBetSignature(signer, account0, 1, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(123, digest);

        vm.expectRevert(SignerMustBeServerError.selector);
        proxy.bet(boutNum, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetWithExpiredDeadline() public {
        // create bout
        uint boutNum = testCreateBout();

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, 1, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp - 1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(SignatureExpiredError.selector);
        proxy.bet(boutNum, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp - 1, v, r, s);
    }

    function testBetWithInsufficientBetAmount() public {
        // create bout
        uint boutNum = testCreateBout();

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, 1, 1, LibConstants.MIN_BET_AMOUNT - 1, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(abi.encodeWithSignature("MinimumBetAmountError(uint256,address,uint256)", 1, address(this), LibConstants.MIN_BET_AMOUNT - 1));
        proxy.bet(boutNum, 1, LibConstants.MIN_BET_AMOUNT - 1, block.timestamp + 1000, v, r, s);
    }

    function testBetWithInvalidBetTarget(uint8 br) public {
        vm.assume(br < 1 || br > 3); // Invalid bet target

        // create bout
        uint boutNum = testCreateBout();

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, 1, br, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(abi.encodeWithSelector(InvalidBetTargetError.selector, 1, address(this), br));
        proxy.bet(boutNum, br, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetWithInsufficentTokens() public {
        // create bout
        uint boutNum = testCreateBout();

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, 1, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        uint256 userBalance = proxy.tokenBalanceOf(LibConstants.TOKEN_MEME, address(this));
        uint256 proxyBalance = proxy.tokenBalanceOf(LibConstants.TOKEN_MEME, address(proxy));

        proxy.bet(boutNum, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);

        assertEq(proxy.tokenBalanceOf(LibConstants.TOKEN_MEME, address(this)), 0, "supporter balance should be 0");
        assertEq(
            proxy.tokenBalanceOf(LibConstants.TOKEN_MEME, address(proxy)),
            proxyBalance + LibConstants.MIN_BET_AMOUNT,
            "proxy balance should have increased by the min bet amount"
        );
    }

    function testBetNewBets() public returns (uint boutNum) {
        // create bout
        boutNum = testCreateBout();

        (Wallet[] memory players, uint[] memory betAmounts, , , , , ) = _getScenario1();

        // place bets
        for (uint i = 0; i < players.length; i += 1) {
            Wallet memory player = players[i];
            _bet(player.addr, boutNum, 1, betAmounts[i]);
        }

        // check bout basic state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutNum);
        assertEq(uint(bout.state), uint(BoutState.Created), "created");
        assertEq(bout.numSupporters, 5, "no. of supporters");
        assertEq(bout.totalPot, LibConstants.MIN_BET_AMOUNT * 15, "total pot");

        // check supporter data
        for (uint i = 1; i <= players.length; i += 1) {
            Wallet memory player = players[i - 1];

            assertEq(proxy.getBoutSupporter(boutNum, i), player.addr, "supporter address");
            assertEq(proxy.getBoutHiddenBet(boutNum, player.addr), 1, "supporter hidden bet");
            assertEq(proxy.getBoutBetAmount(boutNum, player.addr), betAmounts[i - 1], "supporter bet amount");

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
        // create bout
        uint boutNum = testCreateBout();

        for (uint i = 1; i <= 5; i += 1) {
            _bet(player1.addr, boutNum, 1, LibConstants.MIN_BET_AMOUNT * i);
        }

        // check bout basic state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutNum);
        assertEq(uint(bout.state), uint(BoutState.Created), "created");
        assertEq(bout.numSupporters, 1, "no. of supporters");
        assertEq(bout.totalPot, LibConstants.MIN_BET_AMOUNT * 5, "total pot");

        // check supporter data
        assertEq(proxy.getBoutSupporter(boutNum, 1), player1.addr, "supporter address");
        assertEq(proxy.getBoutHiddenBet(boutNum, player1.addr), 1, "supporter hidden bet");
        assertEq(proxy.getBoutBetAmount(boutNum, player1.addr), bout.totalPot, "supporter bet amount");
        assertEq(proxy.getUserBoutsSupported(player1.addr), boutNum, "user supported bouts");

        // check MEME balances
        assertEq(memeToken.balanceOf(player1.addr), LibConstants.MIN_BET_AMOUNT * 10, "MEME balance");
        assertEq(memeToken.balanceOf(address(proxy)), bout.totalPot, "MEME balance");
    }

    function testBetEmitsEvent() public {
        // create bout
        uint boutNum = testCreateBout();

        uint amount = LibConstants.MIN_BET_AMOUNT;

        vm.recordLogs();

        _bet(player1.addr, boutNum, 1, amount);

        // check logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1, "Invalid event count");
        assertEq(entries[0].topics[0], keccak256("BetPlaced(uint256,address)"));
        (uint eBoutNum, address supporter) = abi.decode(entries[0].data, (uint256, address));
        assertEq(eBoutNum, boutNum, "boutNum incorrect");
        assertEq(supporter, player1.addr, "supporter incorrect");
    }

    // ------------------------------------------------------ //
    //
    // Reveal bets
    //
    // ------------------------------------------------------ //

    function testRevealBetsMustBeDoneByServer() public {
        // create bout and place bets
        uint boutNum = testBetNewBets();

        address dummyServer = vm.addr(123);

        uint8[] memory rPacked = new uint8[](0);

        vm.prank(dummyServer);
        vm.expectRevert(CallerMustBeServerError.selector);
        proxy.revealBets(boutNum, 0, rPacked);

        proxy.setAddress(LibConstants.SERVER_ADDRESS, dummyServer);

        vm.prank(dummyServer);
        proxy.revealBets(boutNum, 0, rPacked);
    }

    function testRevealBetsInWrongState() public {
        // create bout and place bets
        uint boutNum = testBetNewBets();

        uint8[] memory rPacked = new uint8[](0);

        // state: Unknown
        proxy._testSetBoutState(boutNum, BoutState.Unknown);
        vm.prank(server.addr);
        vm.expectRevert(abi.encodeWithSelector(BoutInWrongStateError.selector, 1, BoutState.Unknown));
        proxy.revealBets(boutNum, 0, rPacked);

        // state: Ended
        proxy._testSetBoutState(boutNum, BoutState.Ended);
        vm.prank(server.addr);
        vm.expectRevert(abi.encodeWithSelector(BoutInWrongStateError.selector, 1, BoutState.Ended));
        proxy.revealBets(boutNum, 0, rPacked);
    }

    function testRevealBetsEmitsEvent() public {
        // create bout and place bets
        uint boutNum = testBetNewBets();

        uint8[] memory rPacked = new uint8[](2);

        vm.recordLogs();

        vm.prank(server.addr);
        proxy.revealBets(boutNum, 3, rPacked);

        // check logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1, "Invalid event count");
        assertEq(entries[0].topics[0], keccak256("BetsRevealed(uint256,uint256)"));
        (uint eBoutNum, uint count) = abi.decode(entries[0].data, (uint, uint));
        assertEq(eBoutNum, boutNum, "boutNum incorrect");
        assertEq(count, 3, "count incorrect");
    }

    function testRevealBets() public returns (uint boutNum) {
        // create bout and place bets
        boutNum = testBetNewBets();

        (Wallet[] memory players, uint[] memory betAmounts, BoutFighter[] memory betTargets, uint8[] memory rPacked, , , ) = _getScenario1();

        vm.prank(server.addr);
        proxy.revealBets(boutNum, 5, rPacked);

        // num of revealed bets
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutNum);
        assertEq(uint(bout.state), uint(BoutState.BetsRevealed), "state");
        assertGt(bout.revealTime, 0, "reveal time");
        assertEq(bout.numRevealedBets, 5, "num revealed bets (1st call)");

        // now let's check the revealed bets
        for (uint i = 0; i < players.length; i++) {
            assertEq(uint(proxy.getBoutRevealedBet(boutNum, players[i].addr)), uint(betTargets[i]), "revealed bet");
        }

        // check the fighter pots
        uint aPot = betAmounts[0] + betAmounts[2] + betAmounts[4];
        assertEq(proxy.getBoutFighterPot(boutNum, BoutFighter.FighterA), aPot, "fighter A pot");
        assertEq(proxy.getBoutFighterPotBalance(boutNum, BoutFighter.FighterA), aPot, "fighter A pot balance");

        uint bPot = betAmounts[1] + betAmounts[3];
        assertEq(proxy.getBoutFighterPot(boutNum, BoutFighter.FighterB), bPot, "fighter B pot");
        assertEq(proxy.getBoutFighterPotBalance(boutNum, BoutFighter.FighterB), bPot, "fighter B pot balance");
    }

    function testRevealBetsWithMultipleCalls() public {
        // create bout and place bets
        uint boutNum = testBetNewBets();

        (Wallet[] memory players, uint[] memory betAmounts, BoutFighter[] memory betTargets, uint8[] memory rPacked, , , ) = _getScenario1();

        uint8[] memory rPacked1 = new uint8[](1);
        rPacked1[0] = rPacked[0];
        uint8[] memory rPacked2 = new uint8[](1);
        rPacked2[0] = rPacked[1];

        // first call
        vm.prank(server.addr);
        proxy.revealBets(boutNum, 4, rPacked1);

        assertEq(proxy.getBoutNonMappingInfo(boutNum).numRevealedBets, 4, "num revealed bets (1st call)");
        for (uint i = 0; i < 4; i++) {
            assertEq(uint(proxy.getBoutRevealedBet(boutNum, players[i].addr)), uint(betTargets[i]), "revealed bet");
        }
        assertEq(uint(proxy.getBoutRevealedBet(boutNum, player5.addr)), uint(BoutFighter.Unknown), "revealed bet 5");

        // 2nd call
        vm.prank(server.addr);
        proxy.revealBets(boutNum, 1, rPacked2);

        assertEq(proxy.getBoutNonMappingInfo(boutNum).numRevealedBets, 5, "num revealed bets (2nd call)");
        assertEq(uint(proxy.getBoutRevealedBet(boutNum, player5.addr)), uint(BoutFighter.FighterA), "revealed bet 5");

        // check the fighter pots
        uint aPot = betAmounts[0] + betAmounts[2] + betAmounts[4];
        assertEq(proxy.getBoutFighterPot(boutNum, BoutFighter.FighterA), aPot, "fighter A pot");

        uint bPot = betAmounts[1] + betAmounts[3];
        assertEq(proxy.getBoutFighterPot(boutNum, BoutFighter.FighterB), bPot, "fighter B pot");
    }

    function testRevealBetsWithBadRValues() public {
        // create bout and place bets
        uint boutNum = testBetNewBets();

        /*
        Since B+R = 1, we'll use 2 and 3 here to cause an underflow. 
        The bet value should default to 0.

        11 10 11 10, 11 00 00 00
        */
        uint8[] memory rPacked = new uint8[](2);
        rPacked[0] = 238; // 11 10 11 10
        rPacked[1] = 192; // 11 00 00 00

        vm.prank(server.addr);
        proxy.revealBets(boutNum, 5, rPacked);

        // now let's check the revealed bets
        assertEq(uint(proxy.getBoutRevealedBet(boutNum, player1.addr)), uint(BoutFighter.FighterA), "revealed bet 1");
        assertEq(uint(proxy.getBoutRevealedBet(boutNum, player2.addr)), uint(BoutFighter.FighterA), "revealed bet 2");
        assertEq(uint(proxy.getBoutRevealedBet(boutNum, player3.addr)), uint(BoutFighter.FighterA), "revealed bet 3");
        assertEq(uint(proxy.getBoutRevealedBet(boutNum, player4.addr)), uint(BoutFighter.FighterA), "revealed bet 4");
        assertEq(uint(proxy.getBoutRevealedBet(boutNum, player5.addr)), uint(BoutFighter.FighterA), "revealed bet 5");

        // check the fighter pots
        assertEq(proxy.getBoutFighterPot(boutNum, BoutFighter.FighterA), proxy.getBoutNonMappingInfo(boutNum).totalPot, "fighter A pot");
        assertEq(proxy.getBoutFighterPot(boutNum, BoutFighter.FighterB), 0, "fighter B pot");
    }

    function testRevealBetsWhenAlreadyFullyRevealed() public {
        // create bout and place bets
        uint boutNum = testBetNewBets();

        vm.startPrank(server.addr);

        uint8[] memory rPacked = new uint8[](2);
        proxy.revealBets(boutNum, 5, rPacked);

        // doing again should do nothing
        proxy.revealBets(boutNum, 1, rPacked);

        assertEq(proxy.getBoutNonMappingInfo(boutNum).numRevealedBets, 5, "num revealed bets");

        vm.stopPrank();
    }

    // ------------------------------------------------------ //
    //
    // End bout
    //
    // ------------------------------------------------------ //

    function testEndBoutMustBeDoneByServer() public {
        // create bout, place bets, reveal bets
        uint boutNum = testRevealBets();

        address dummyServer = vm.addr(123);

        vm.prank(dummyServer);
        vm.expectRevert(CallerMustBeServerError.selector);
        proxy.endBout(boutNum, BoutFighter.FighterA);

        proxy.setAddress(LibConstants.SERVER_ADDRESS, dummyServer);

        vm.prank(dummyServer);
        proxy.endBout(boutNum, BoutFighter.FighterA);
    }

    function testEndBoutEmitsEvent() public {
        // create bout, place bets, reveal bets
        uint boutNum = testRevealBets();

        vm.recordLogs();

        vm.prank(server.addr);
        proxy.endBout(boutNum, BoutFighter.FighterA);

        // check logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1, "Invalid event count");
        assertEq(entries[0].topics[0], keccak256("BoutEnded(uint256)"));
        uint eBoutNum = abi.decode(entries[0].data, (uint));
        assertEq(eBoutNum, boutNum, "boutNum incorrect");
    }

    function testEndBoutWithInvalidState() public {
        // create bout, place bets, reveal bets
        uint boutNum = testRevealBets();

        vm.startPrank(server.addr);

        // state: Unknown
        proxy._testSetBoutState(boutNum, BoutState.Unknown);
        vm.expectRevert(abi.encodeWithSelector(BoutInWrongStateError.selector, 1, BoutState.Unknown));
        proxy.endBout(boutNum, BoutFighter.FighterA);

        // state: Created
        proxy._testSetBoutState(boutNum, BoutState.Created);
        vm.expectRevert(abi.encodeWithSelector(BoutInWrongStateError.selector, 1, BoutState.Created));
        proxy.endBout(boutNum, BoutFighter.FighterA);

        // state: Ended
        proxy._testSetBoutState(boutNum, BoutState.Ended);
        vm.expectRevert(abi.encodeWithSelector(BoutInWrongStateError.selector, 1, BoutState.Ended));
        proxy.endBout(boutNum, BoutFighter.FighterA);

        vm.stopPrank();
    }

    function testEndBoutWithInvalidWinner() public {
        // create bout, place bets, reveal bets
        uint boutNum = testRevealBets();

        vm.prank(server.addr);
        vm.expectRevert(abi.encodeWithSelector(InvalidWinnerError.selector, 1, BoutFighter.Unknown));
        proxy.endBout(boutNum, BoutFighter.Unknown);
    }

    function testEndBout() public returns (uint boutNum) {
        // create bout, place bets, reveal bets
        boutNum = testRevealBets();

        (, , , , BoutFighter winner, BoutFighter loser, ) = _getScenario1();

        vm.prank(server.addr);
        proxy.endBout(boutNum, winner);

        // check the state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutNum);
        assertEq(uint(bout.state), uint(BoutState.Ended), "state");
        assertGt(bout.endTime, 0, "end time");
        assertEq(uint(bout.winner), uint(winner), "winner");
        assertEq(uint(bout.loser), uint(loser), "loser");

        // check global state
        assertEq(proxy.getEndedBouts(), boutNum, "ended bouts");
    }

    // ------------------------------------------------------ //
    //
    // Test processing multiple bouts
    //
    // ------------------------------------------------------ //

    function testCompleteMultipleBouts() internal returns (uint[] memory boutNums) {
        (
            Wallet[] memory players,
            uint[] memory betAmounts,
            BoutFighter[] memory betTargets,
            uint8[] memory rPacked,
            BoutFighter winner,
            BoutFighter loser,
            uint[] memory expectedWinnings
        ) = _getScenario1();

        boutNums = new uint[](5);

        // create bout, place bets, reveal bets, end bout
        for (uint i = 0; i < 5; i += 1) {
            vm.prank(server.addr);
            proxy.createBout(fighterAId, fighterBId);

            boutNums[i] = proxy.getTotalBouts();

            for (uint j = 0; j < players.length; j += 1) {
                _bet(players[j].addr, boutNums[i], 1, betAmounts[j]);
            }

            vm.startPrank(server.addr);
            proxy.revealBets(boutNums[i], 5, rPacked);
            proxy.endBout(boutNums[i], winner);
            vm.stopPrank();
        }

        // check total bouts
        assertEq(proxy.getTotalBouts(), boutNums.length, "total bouts");
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
        uint[] memory boutNums = testCompleteMultipleBouts();

        (Wallet[] memory players, , , , , , uint[] memory expectedWinnings) = _getScenario1();

        // check claimable winnings
        for (uint i = 0; i < players.length; i++) {
            Wallet memory player = players[i];

            uint winnings = proxy.getClaimableWinnings(player.addr);

            assertEq(winnings, expectedWinnings[i] * boutNums.length, "winnings");
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
        uint boutNum = testEndBout();

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
            v.winnerPotPrevBalance = proxy.getBoutFighterPotBalance(boutNum, winner);
            v.loserPotPrevBalance = proxy.getBoutFighterPotBalance(boutNum, loser);

            // get meme token balance of proxy
            v.proxyMemeTokenBalance = memeToken.balanceOf(proxyAddress);

            // get bout winnings for this player
            (v.total, v.selfAmount, v.won) = proxy.getBoutWinnings(boutNum, player.addr);

            // make claim
            proxy.claimWinnings(player.addr, 1);

            // check fighter pot balances
            v.winnerPotPostBalance = proxy.getBoutFighterPotBalance(boutNum, winner);
            v.loserPotPostBalance = proxy.getBoutFighterPotBalance(boutNum, loser);
            if (betTargets[i] == winner) {
                assertEq(v.winnerPotPostBalance, v.winnerPotPrevBalance - v.selfAmount);
                assertEq(v.loserPotPostBalance, v.loserPotPrevBalance - v.won);
            } else {
                assertEq(v.winnerPotPostBalance, v.winnerPotPrevBalance);
                assertEq(v.loserPotPostBalance, v.loserPotPrevBalance);
            }

            // check bout winnings claimed status
            assertEq(proxy.getBoutWinningsClaimed(boutNum, player.addr), true, "bout winnings claimed");

            // check that tokens were transferred
            assertEq(memeToken.balanceOf(player.addr), v.total, "total winnings");
            assertEq(memeToken.balanceOf(proxyAddress), v.proxyMemeTokenBalance - v.total, "proxy meme token balance");

            // check that there no more winnings to claim for this player
            assertEq(proxy.getClaimableWinnings(player.addr), 0, "all winnings claimed");
        }
    }

    function testClaimWinningsForMultipleBouts() public {
        // create bout, place bets, reveal bets, end bout
        uint[] memory boutNums = testCompleteMultipleBouts();

        (
            Wallet[] memory players,
            uint[] memory betAmounts,
            BoutFighter[] memory betTargets,
            ,
            BoutFighter winner,
            BoutFighter loser,
            uint[] memory expectedWinnings
        ) = _getScenario1();

        ClaimWinningsLoopValues[] memory v = new ClaimWinningsLoopValues[](boutNums.length);
        Wallet memory player = players[1]; // 2nd and 4th players are winners
        assertEq(uint(betTargets[1]), uint(winner));

        uint winningsClaimed = 0;
        uint totalWinnings = proxy.getClaimableWinnings(player.addr);
        uint proxyMemeTokenBalance = memeToken.balanceOf(proxyAddress);

        // get pre-values
        for (uint i = 0; i < boutNums.length; i++) {
            uint boutNum = boutNums[i];

            // get fighter pot balances
            v[i].winnerPotPrevBalance = proxy.getBoutFighterPotBalance(boutNum, winner);
            v[i].loserPotPrevBalance = proxy.getBoutFighterPotBalance(boutNum, loser);

            // get bout winnings for this player
            (v[i].total, v[i].selfAmount, v[i].won) = proxy.getBoutWinnings(boutNum, player.addr);

            winningsClaimed += v[i].total;
        }

        // have winnings to claim
        assertGt(winningsClaimed, 0, "have winnings to claim");
        assertEq(winningsClaimed, totalWinnings, "have winnings to claim equal to total");

        // make claim
        proxy.claimWinnings(player.addr, boutNums.length);

        // check post-values
        for (uint i = 0; i < boutNums.length; i++) {
            uint boutNum = boutNums[i];

            // check fighter pot balances
            v[i].winnerPotPostBalance = proxy.getBoutFighterPotBalance(boutNum, winner);
            v[i].loserPotPostBalance = proxy.getBoutFighterPotBalance(boutNum, loser);
            assertEq(v[i].winnerPotPostBalance, v[i].winnerPotPrevBalance - v[i].selfAmount);
            assertEq(v[i].loserPotPostBalance, v[i].loserPotPrevBalance - v[i].won);

            // check bout winnings claimed status
            assertEq(proxy.getBoutWinningsClaimed(boutNum, player.addr), true, "bout winnings claimed");
        }

        // check that tokens were transferred
        assertEq(memeToken.balanceOf(player.addr), winningsClaimed, "total winnings");
        assertEq(memeToken.balanceOf(proxyAddress), proxyMemeTokenBalance - winningsClaimed, "proxy meme token balance");

        // check that there no more winnings to claim for this player
        assertEq(proxy.getClaimableWinnings(player.addr), 0, "all winnings claimed");
    }

    function testClaimWinningsForMultipleBoutsSubset() public {
        // create bout, place bets, reveal bets, end bout
        uint[] memory boutNums = testCompleteMultipleBouts();

        (
            Wallet[] memory players,
            uint[] memory betAmounts,
            BoutFighter[] memory betTargets,
            ,
            BoutFighter winner,
            BoutFighter loser,
            uint[] memory expectedWinnings
        ) = _getScenario1();

        ClaimWinningsLoopValues[] memory v = new ClaimWinningsLoopValues[](boutNums.length);
        Wallet memory player = players[1]; // 2nd and 4th players are winners
        assertEq(uint(betTargets[1]), uint(winner));

        uint winningsClaimed = 0;
        uint totalWinnings = proxy.getClaimableWinnings(player.addr);
        uint proxyMemeTokenBalance = memeToken.balanceOf(proxyAddress);

        uint MAX_BOUTS = 2;

        // get pre-values
        for (uint i = 0; i < MAX_BOUTS; i++) {
            uint boutNum = boutNums[i];

            // get fighter pot balances
            v[i].winnerPotPrevBalance = proxy.getBoutFighterPotBalance(boutNum, winner);
            v[i].loserPotPrevBalance = proxy.getBoutFighterPotBalance(boutNum, loser);

            // get bout winnings for this player
            (v[i].total, v[i].selfAmount, v[i].won) = proxy.getBoutWinnings(boutNum, player.addr);

            winningsClaimed += v[i].total;
        }

        assertGt(winningsClaimed, 0, "have winnings to claim");
        assertLt(winningsClaimed, totalWinnings, "have winnings to claim less than total");

        // make claim
        proxy.claimWinnings(player.addr, MAX_BOUTS);

        // check post-values
        for (uint i = 0; i < MAX_BOUTS; i++) {
            uint boutNum = boutNums[i];

            // check fighter pot balances
            v[i].winnerPotPostBalance = proxy.getBoutFighterPotBalance(boutNum, winner);
            v[i].loserPotPostBalance = proxy.getBoutFighterPotBalance(boutNum, loser);
            assertEq(v[i].winnerPotPostBalance, v[i].winnerPotPrevBalance - v[i].selfAmount);
            assertEq(v[i].loserPotPostBalance, v[i].loserPotPrevBalance - v[i].won);

            // check bout winnings claimed status
            assertEq(proxy.getBoutWinningsClaimed(boutNum, player.addr), true, "bout winnings claimed");
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

    function _bet(address supporter, uint boutNum, uint8 br, uint amount) internal {
        // mint tokens
        proxy._testMintMeme(supporter, amount);

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, supporter, boutNum, br, amount, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.prank(supporter);
        proxy.bet(boutNum, br, amount, block.timestamp + 1000, v, r, s);
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
