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

    function testCreateBout() public {
        assertEq(proxy.getTotalBouts(), 0, "no bouts");

        // create
        vm.prank(server.addr);
        proxy.createBout(fighterAId, fighterBId);

        // check bout count updated
        assertEq(proxy.getTotalBouts(), 1, "1 bout");

        // check basic bout info
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(1);
        assertEq(bout.id, 1, "bout id");
        assertEq(uint(bout.state), uint(BoutState.Created), "created");
        assertEq(uint(bout.winner), uint(BoutFighter.Unknown), "winner not set");
        assertEq(uint(bout.loser), uint(BoutFighter.Unknown), "loser not set");

        // check bout fighters
        assertEq(proxy.getBoutFighterId(1, BoutFighter.FighterA), fighterAId, "fighterAId");
        assertEq(proxy.getBoutFighterId(1, BoutFighter.FighterB), fighterBId, "fighterBId");
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
        testCreateBout();

        // state: Unknown
        proxy._testSetBoutState(1, BoutState.Unknown);
        vm.expectRevert(BoutInWrongStateError.selector);
        proxy.bet(1, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, 1, "0x", "0x");

        // state: BetsRevealed
        proxy._testSetBoutState(1, BoutState.BetsRevealed);
        vm.expectRevert(BoutInWrongStateError.selector);
        proxy.bet(1, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, 1, "0x", "0x");

        // state: Ended
        proxy._testSetBoutState(1, BoutState.Ended);
        vm.expectRevert(BoutInWrongStateError.selector);
        proxy.bet(1, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, 1, "0x", "0x");
    }

    function testBetWithBadSigner() public {
        // create bout
        testCreateBout();

        // do signature
        address signer = vm.addr(123);
        bytes32 digest = proxy.calculateBetSignature(signer, account0, 1, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(123, digest);

        vm.expectRevert(SignerMustBeServerError.selector);
        proxy.bet(1, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetWithExpiredDeadline() public {
        // create bout
        testCreateBout();

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, 1, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp - 1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(SignatureExpiredError.selector);
        proxy.bet(1, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp - 1, v, r, s);
    }

    function testBetWithInsufficientBetAmount() public {
        // create bout
        testCreateBout();

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, 1, 1, LibConstants.MIN_BET_AMOUNT - 1, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(MinimumBetAmountError.selector);
        proxy.bet(1, 1, LibConstants.MIN_BET_AMOUNT - 1, block.timestamp + 1000, v, r, s);
    }

    function testBetWithInvalidBetTarget(uint8 br) public {
        vm.assume(br < 1 || br > 3); // Invalid bet target

        // create bout
        testCreateBout();

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, 1, br, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(InvalidBetTargetError.selector);
        proxy.bet(1, br, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetWithInsufficentTokens() public {
        // create bout
        testCreateBout();

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, 1, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(TokenBalanceInsufficient.selector);
        proxy.bet(1, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetNewBets() public {
        // create bout
        testCreateBout();

        Wallet[] memory players = getPlayers();
        uint[] memory betAmounts = new uint[](players.length);

        // place bets
        for (uint i = 0; i < players.length; i += 1) {
            Wallet memory player = players[i];

            // increasing bet amounts
            betAmounts[i] = LibConstants.MIN_BET_AMOUNT * (i + 1);

            _bet(player.addr, 1, 1, betAmounts[i]);
        }

        // check bout basic state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(1);
        assertEq(uint(bout.state), uint(BoutState.Created), "created");
        assertEq(bout.numSupporters, 5, "no. of supporters");
        assertEq(bout.totalPot, LibConstants.MIN_BET_AMOUNT * 15, "total pot");

        // check supporter data
        for (uint i = 1; i <= players.length; i += 1) {
            Wallet memory player = players[i - 1];

            assertEq(proxy.getBoutSupporter(1, i), player.addr, "supporter address");
            assertEq(proxy.getBoutHiddenBet(1, player.addr), 1, "supporter hidden bet");
            assertEq(proxy.getBoutBetAmount(1, player.addr), betAmounts[i - 1], "supporter bet amount");
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
        testCreateBout();

        for (uint i = 1; i <= 5; i += 1) {
            _bet(player1.addr, 1, 1, LibConstants.MIN_BET_AMOUNT * i);
        }

        // check bout basic state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(1);
        assertEq(uint(bout.state), uint(BoutState.Created), "created");
        assertEq(bout.numSupporters, 1, "no. of supporters");
        assertEq(bout.totalPot, LibConstants.MIN_BET_AMOUNT * 5, "total pot");

        // // check supporter data
        assertEq(proxy.getBoutSupporter(1, 1), player1.addr, "supporter address");
        assertEq(proxy.getBoutHiddenBet(1, player1.addr), 1, "supporter hidden bet");
        assertEq(proxy.getBoutBetAmount(1, player1.addr), bout.totalPot, "supporter bet amount");

        // check MEME balances
        assertEq(memeToken.balanceOf(player1.addr), LibConstants.MIN_BET_AMOUNT * 10, "MEME balance");
        assertEq(memeToken.balanceOf(address(proxy)), bout.totalPot, "MEME balance");
    }

    function testBetEmitsEvent() public {
        // create bout
        testCreateBout();

        uint amount = LibConstants.MIN_BET_AMOUNT;

        vm.recordLogs();

        _bet(player1.addr, 1, 1, amount);

        // check logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1, "Invalid event count");
        assertEq(entries[0].topics[0], keccak256("BetPlaced(uint256,address)"));
        (uint boutNum, address supporter) = abi.decode(entries[0].data, (uint256, address));
        assertEq(boutNum, 1, "boutNum incorrect");
        assertEq(supporter, player1.addr, "supporter incorrect");
    }

    // ------------------------------------------------------ //
    //
    // Reveal bets
    //
    // ------------------------------------------------------ //

    function testRevealBetsMustBeDoneByServer() public {
        // create bout and place bets
        testBetNewBets();

        address dummyServer = vm.addr(123);

        uint8[] memory rPacked = new uint8[](0);

        vm.prank(dummyServer);
        vm.expectRevert(CallerMustBeServerError.selector);
        proxy.revealBets(1, 0, rPacked);

        proxy.setAddress(LibConstants.SERVER_ADDRESS, dummyServer);

        vm.prank(dummyServer);
        proxy.revealBets(1, 0, rPacked);
    }

    function testRevealBetsInWrongState() public {
        // create bout and place bets
        testBetNewBets();

        uint8[] memory rPacked = new uint8[](0);

        // state: Unknown
        proxy._testSetBoutState(1, BoutState.Unknown);
        vm.prank(server.addr);
        vm.expectRevert(BoutInWrongStateError.selector);
        proxy.revealBets(1, 0, rPacked);

        // state: Ended
        proxy._testSetBoutState(1, BoutState.Ended);
        vm.prank(server.addr);
        vm.expectRevert(BoutInWrongStateError.selector);
        proxy.revealBets(1, 0, rPacked);
    }

    function testRevealBetsEmitsEvent() public {
        // create bout and place bets
        testBetNewBets();

        uint8[] memory rPacked = new uint8[](2);

        vm.recordLogs();

        vm.prank(server.addr);
        proxy.revealBets(1, 3, rPacked);

        // check logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1, "Invalid event count");
        assertEq(entries[0].topics[0], keccak256("BetsRevealed(uint256,uint256)"));
        (uint boutNum, uint count) = abi.decode(entries[0].data, (uint, uint));
        assertEq(boutNum, 1, "boutNum incorrect");
        assertEq(count, 3, "count incorrect");
    }

    function testRevealBets() public {
        // create bout and place bets
        testBetNewBets();

        /*
        5 players, odd ones will bet for fighterA, even for fighterB

        Thus, 2 bytes with bit pattern:

        01 00 01 00, 01 00 00 00
        */
        uint8[] memory rPacked = new uint8[](2);
        rPacked[0] = 68; // 01000100
        rPacked[1] = 64; // 01000000

        vm.prank(server.addr);
        proxy.revealBets(1, 5, rPacked);

        // num of revealed bets
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(1);
        assertEq(uint(bout.state), uint(BoutState.BetsRevealed), "state");
        assertGt(bout.revealTime, 0, "reveal time");
        assertEq(bout.numRevealedBets, 5, "num revealed bets (1st call)");

        // now let's check the revealed bets
        assertEq(uint(proxy.getBoutRevealedBet(1, player1.addr)), uint(BoutFighter.FighterA), "revealed bet 1");
        assertEq(uint(proxy.getBoutRevealedBet(1, player2.addr)), uint(BoutFighter.FighterB), "revealed bet 2");
        assertEq(uint(proxy.getBoutRevealedBet(1, player3.addr)), uint(BoutFighter.FighterA), "revealed bet 3");
        assertEq(uint(proxy.getBoutRevealedBet(1, player4.addr)), uint(BoutFighter.FighterB), "revealed bet 4");
        assertEq(uint(proxy.getBoutRevealedBet(1, player5.addr)), uint(BoutFighter.FighterA), "revealed bet 5");

        // check the fighter pots
        uint aPot = proxy.getBoutBetAmount(1, player1.addr) + proxy.getBoutBetAmount(1, player3.addr) + proxy.getBoutBetAmount(1, player5.addr);
        assertEq(proxy.getBoutFighterPot(1, BoutFighter.FighterA), aPot, "fighter A pot");

        uint bPot = proxy.getBoutBetAmount(1, player2.addr) + proxy.getBoutBetAmount(1, player4.addr);
        assertEq(proxy.getBoutFighterPot(1, BoutFighter.FighterB), bPot, "fighter B pot");
    }

    function testRevealBetsWithMultipleCalls() public {
        // create bout and place bets
        testBetNewBets();

        /*
        5 players, odd ones will bet for fighterA, even for fighterB

        Thus, 2 bytes with bit pattern:

        01 00 01 00, 01 00 00 00

        We'll do 2 calls, 1 for each byte
        */
        uint8[] memory rPacked1 = new uint8[](1);
        rPacked1[0] = 68; // 01 00 01 00
        uint8[] memory rPacked2 = new uint8[](1);
        rPacked2[0] = 64; // 01 00 00 00

        // first call
        vm.prank(server.addr);
        proxy.revealBets(1, 4, rPacked1);

        assertEq(proxy.getBoutNonMappingInfo(1).numRevealedBets, 4, "num revealed bets (1st call)");
        assertEq(uint(proxy.getBoutRevealedBet(1, player1.addr)), uint(BoutFighter.FighterA), "revealed bet 1");
        assertEq(uint(proxy.getBoutRevealedBet(1, player2.addr)), uint(BoutFighter.FighterB), "revealed bet 2");
        assertEq(uint(proxy.getBoutRevealedBet(1, player3.addr)), uint(BoutFighter.FighterA), "revealed bet 3");
        assertEq(uint(proxy.getBoutRevealedBet(1, player4.addr)), uint(BoutFighter.FighterB), "revealed bet 4");
        assertEq(uint(proxy.getBoutRevealedBet(1, player5.addr)), uint(BoutFighter.Unknown), "revealed bet 5");

        // 2nd call
        vm.prank(server.addr);
        proxy.revealBets(1, 1, rPacked2);

        assertEq(proxy.getBoutNonMappingInfo(1).numRevealedBets, 5, "num revealed bets (2nd call)");
        assertEq(uint(proxy.getBoutRevealedBet(1, player5.addr)), uint(BoutFighter.FighterA), "revealed bet 5");

        // check the fighter pots
        uint aPot = proxy.getBoutBetAmount(1, player1.addr) + proxy.getBoutBetAmount(1, player3.addr) + proxy.getBoutBetAmount(1, player5.addr);
        assertEq(proxy.getBoutFighterPot(1, BoutFighter.FighterA), aPot, "fighter A pot");

        uint bPot = proxy.getBoutBetAmount(1, player2.addr) + proxy.getBoutBetAmount(1, player4.addr);
        assertEq(proxy.getBoutFighterPot(1, BoutFighter.FighterB), bPot, "fighter B pot");
    }

    function testRevealBetsWithBadRValues() public {
        // create bout and place bets
        testBetNewBets();

        /*
        Since B+R = 1, we'll use 2 and 3 here to cause an underflow. 
        The bet value should default to 0.

        11 10 11 10, 11 00 00 00
        */
        uint8[] memory rPacked = new uint8[](2);
        rPacked[0] = 238; // 11 10 11 10
        rPacked[1] = 192; // 11 00 00 00

        vm.prank(server.addr);
        proxy.revealBets(1, 5, rPacked);

        // now let's check the revealed bets
        assertEq(uint(proxy.getBoutRevealedBet(1, player1.addr)), uint(BoutFighter.FighterA), "revealed bet 1");
        assertEq(uint(proxy.getBoutRevealedBet(1, player2.addr)), uint(BoutFighter.FighterA), "revealed bet 2");
        assertEq(uint(proxy.getBoutRevealedBet(1, player3.addr)), uint(BoutFighter.FighterA), "revealed bet 3");
        assertEq(uint(proxy.getBoutRevealedBet(1, player4.addr)), uint(BoutFighter.FighterA), "revealed bet 4");
        assertEq(uint(proxy.getBoutRevealedBet(1, player5.addr)), uint(BoutFighter.FighterA), "revealed bet 5");

        // check the fighter pots
        assertEq(proxy.getBoutFighterPot(1, BoutFighter.FighterA), proxy.getBoutNonMappingInfo(1).totalPot, "fighter A pot");
        assertEq(proxy.getBoutFighterPot(1, BoutFighter.FighterB), 0, "fighter B pot");
    }

    function testRevealBetsWhenAlreadyFullyRevealed() public {
        // create bout and place bets
        testBetNewBets();

        vm.startPrank(server.addr);

        uint8[] memory rPacked = new uint8[](2);
        proxy.revealBets(1, 5, rPacked);

        vm.expectRevert(BoutAlreadyFullyRevealedError.selector);
        proxy.revealBets(1, 1, rPacked);

        vm.stopPrank();
    }

    // ------------------------------------------------------ //
    //
    // End bout
    //
    // ------------------------------------------------------ //

    function testEndBoutMustBeDoneByServer() public {
        // create bout, place bets, reveal bets
        testRevealBets();

        address dummyServer = vm.addr(123);

        vm.prank(dummyServer);
        vm.expectRevert(CallerMustBeServerError.selector);
        proxy.endBout(1, BoutFighter.FighterA);

        proxy.setAddress(LibConstants.SERVER_ADDRESS, dummyServer);

        vm.prank(dummyServer);
        proxy.endBout(1, BoutFighter.FighterA);
    }

    function testEndBoutEmitsEvent() public {
        // create bout, place bets, reveal bets
        testRevealBets();

        vm.recordLogs();

        vm.prank(server.addr);
        proxy.endBout(1, BoutFighter.FighterA);

        // check logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1, "Invalid event count");
        assertEq(entries[0].topics[0], keccak256("BoutEnded(uint256)"));
        uint boutNum = abi.decode(entries[0].data, (uint));
        assertEq(boutNum, 1, "boutNum incorrect");
    }

    function testEndBoutWithInvalidState() public {
        // create bout, place bets, reveal bets
        testRevealBets();

        vm.startPrank(server.addr);

        // state: Unknown
        proxy._testSetBoutState(1, BoutState.Unknown);
        vm.expectRevert(BoutInWrongStateError.selector);
        proxy.endBout(1, BoutFighter.FighterA);

        // state: Created
        proxy._testSetBoutState(1, BoutState.Created);
        vm.expectRevert(BoutInWrongStateError.selector);
        proxy.endBout(1, BoutFighter.FighterA);

        // state: Ended
        proxy._testSetBoutState(1, BoutState.Ended);
        vm.expectRevert(BoutInWrongStateError.selector);
        proxy.endBout(1, BoutFighter.FighterA);

        vm.stopPrank();
    }

    function testEndBoutWithInvalidWinner() public {
        // create bout, place bets, reveal bets
        testRevealBets();

        vm.prank(server.addr);
        vm.expectRevert(InvalidWinnerError.selector);
        proxy.endBout(1, BoutFighter.Unknown);
    }

    function testEndBout() public {
        // create bout, place bets, reveal bets
        testRevealBets();

        vm.prank(server.addr);
        proxy.endBout(1, BoutFighter.FighterB);

        // check the state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(1);
        assertEq(uint(bout.state), uint(BoutState.Ended), "state");
        assertGt(bout.endTime, 0, "end time");
        assertEq(uint(bout.winner), uint(BoutFighter.FighterB), "winner");
        assertEq(uint(bout.loser), uint(BoutFighter.FighterA), "loser");

        // check global state
        assertEq(proxy.getEndedBouts(), 1, "ended bouts");
    }

    // ------------------------------------------------------ //
    //
    // Claim winnings
    //
    // ------------------------------------------------------ //

    // TODO...

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
}
