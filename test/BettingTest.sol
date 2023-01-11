// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import "../src/Errors.sol";
import { BoutNonMappingInfo, BoutFighter, BoutState } from "../src/Objects.sol";
import { Wallet, TestBaseContract } from "./utils/TestBaseContract.sol";
import { LibConstants } from "../src/libs/LibConstants.sol";

contract Supporters is TestBaseContract {
    uint fighterAId = 1;
    uint fighterBId = 2;

    function setUp() public override {
        super.setUp();
    }

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

    function testRevealBetsMustBeDoneByServer() public {
        // create bout and place bets
        testBetNewBets();

        address dummyServer = vm.addr(123);

        uint8[] memory rPacked = new uint8[](0);

        vm.prank(dummyServer);
        vm.expectRevert(CallerMustBeServerError.selector);
        proxy.revealBets(1, rPacked);

        proxy.setAddress(LibConstants.SERVER_ADDRESS, dummyServer);

        vm.prank(dummyServer);
        proxy.revealBets(1, rPacked);
    }

    function testRevealBetsInWrongState() public {
        // create bout and place bets
        testBetNewBets();

        uint8[] memory rPacked = new uint8[](0);

        // state: Unknown
        proxy._testSetBoutState(1, BoutState.Unknown);
        vm.prank(server.addr);
        vm.expectRevert(BoutInWrongStateError.selector);
        proxy.revealBets(1, rPacked);

        // state: Ended
        proxy._testSetBoutState(1, BoutState.Ended);
        vm.prank(server.addr);
        vm.expectRevert(BoutInWrongStateError.selector);
        proxy.revealBets(1, rPacked);
    }

    function testRevealBetsUpdatesBasicState() public {
        // create bout and place bets
        testBetNewBets();

        uint8[] memory rPacked = new uint8[](0);

        vm.prank(server.addr);
        proxy.revealBets(1, rPacked);

        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(1);
        assertEq(uint(bout.state), uint(BoutState.BetsRevealed), "state");
        assertGt(bout.revealTime, 0, "reveal time");
    }

    function testRevealBetsEmitsEvent() public {
        // create bout and place bets
        testBetNewBets();

        uint8[] memory rPacked = new uint8[](2);

        vm.recordLogs();

        vm.prank(server.addr);
        proxy.revealBets(1, rPacked);

        // check logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1, "Invalid event count");
        assertEq(entries[0].topics[0], keccak256("BetsRevealed(uint256,uint256)"));
        (uint boutNum, uint count) = abi.decode(entries[0].data, (uint, uint));
        assertEq(boutNum, 1, "boutNum incorrect");
        assertEq(count, 5, "count incorrect");
    }

    function testRevealBetsUpdatesPotsAndRevealedBets() public {
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
        proxy.revealBets(1, rPacked);

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
