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
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        // state: Ended
        proxy._testSetBoutState(boutId, BoutState.Ended);
        vm.expectRevert(abi.encodePacked(BoutInWrongStateError.selector, uint(100), uint256(BoutState.Ended)));
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);

        // state: Cancelled
        proxy._testSetBoutState(boutId, BoutState.Cancelled);
        vm.expectRevert(abi.encodePacked(BoutInWrongStateError.selector, uint(100), uint256(BoutState.Cancelled)));
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetWithBadSigner() public {
        uint boutId = 100;

        // do signature
        address signer = vm.addr(123);
        bytes32 digest = proxy.calculateBetSignature(signer, account0, boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(123, digest);

        vm.expectRevert(SignerMustBeServerError.selector);
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetWithExpiredDeadline() public {
        uint boutId = 100;

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp - 1);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(SignatureExpiredError.selector);
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp - 1, v, r, s);
    }

    function testBetWithInsufficientBetAmount() public {
        uint boutId = 100;

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, boutId, 1, LibConstants.MIN_BET_AMOUNT - 1, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(abi.encodeWithSelector(MinimumBetAmountError.selector, uint(boutId), address(this), LibConstants.MIN_BET_AMOUNT - 1));
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT - 1, block.timestamp + 1000, v, r, s);
    }

    function testBetWithInvalidBetTarget(uint8 br) public {
        vm.assume(br < 1 || br > 3); // Invalid bet target

        uint boutId = 100;

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, boutId, br, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        vm.expectRevert(abi.encodeWithSelector(InvalidBetTargetError.selector, boutId, address(this), br));
        proxy.bet(boutId, br, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetWithInsufficentTokens() public {
        uint boutId = 100;

        // do signature
        bytes32 digest = proxy.calculateBetSignature(server.addr, account0, boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(server.privateKey, digest);

        uint256 userBalance = proxy.tokenBalanceOf(LibTokenIds.TOKEN_MEME, address(this));

        vm.expectRevert(abi.encodeWithSelector(TokenBalanceInsufficient.selector, userBalance, LibConstants.MIN_BET_AMOUNT));
        proxy.bet(boutId, 1, LibConstants.MIN_BET_AMOUNT, block.timestamp + 1000, v, r, s);
    }

    function testBetSetsUpBoutState() public returns (uint boutId) {
        boutId = 100;

        (Wallet[] memory players, uint[] memory betAmounts, , , , , ) = _getScenario1();

        // initialy no bouts
        assertEq(proxy.getTotalBouts(), 0, "no bouts at start");

        // place bet
        Wallet memory player = players[0];
        _bet(player.addr, boutId, 1, betAmounts[0]);

        // check total bouts
        assertEq(proxy.getTotalBouts(), 1, "total bouts");
        assertEq(proxy.getBoutIdByIndex(1), boutId, "bout id by index");

        // check bout basic state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(uint(bout.state), uint(BoutState.Created), "created");
        assertEq(bout.numSupporters, 1, "no. of bettors");
        assertEq(bout.totalPot, betAmounts[0], "total pot");
        assertEq(uint(bout.winner), uint(BoutFighter.Uninitialized), "bout winner");
        assertEq(uint(bout.loser), uint(BoutFighter.Uninitialized), "bout loser");

        assertEq(proxy.getBoutFighterPot(boutId, BoutFighter.FighterA), 0, "fighter A pot");
        assertEq(proxy.getBoutFighterPot(boutId, BoutFighter.FighterB), 0, "fighter B pot");
        assertEq(proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterA), 0, "fighter A pot balance");
        assertEq(proxy.getBoutFighterPotBalance(boutId, BoutFighter.FighterB), 0, "fighter B pot balance");

        // check player data
        assertEq(proxy.getBoutSupporter(boutId, 1), player.addr, "bettor address");
        assertEq(proxy.getBoutHiddenBet(boutId, player.addr), 1, "bettor hidden bet");
        assertEq(proxy.getBoutBetAmount(boutId, player.addr), betAmounts[0], "bettor bet amount");
        assertEq(proxy.getUserBoutsSupported(player.addr), 1, "user supported bouts");

        // check MEME balances
        assertEq(memeToken.balanceOf(player.addr), 0, "MEME balance");
        assertEq(memeToken.balanceOf(address(proxy)), bout.totalPot, "MEME balance");
    }

    function testBetMultipleSucceeds() public returns (uint boutId) {
        boutId = 100;

        (Wallet[] memory players, uint[] memory betAmounts, , , , , ) = _getScenario1();

        // place bets
        uint totalBetAmount = 0;
        for (uint i = 0; i < players.length; i += 1) {
            Wallet memory player = players[i];
            totalBetAmount += betAmounts[i];
            _bet(player.addr, boutId, 1, betAmounts[i]);
        }

        // check total bouts
        assertEq(proxy.getTotalBouts(), 1, "still only 1 bout created");
        assertEq(proxy.getBoutIdByIndex(1), boutId, "bout id by index");

        // check bout basic state
        BoutNonMappingInfo memory bout = proxy.getBoutNonMappingInfo(boutId);
        assertEq(bout.numSupporters, 5, "no. of bettors");
        assertEq(bout.totalPot, totalBetAmount, "total pot");

        // check bettor data
        for (uint i = 0; i < players.length; i += 1) {
            Wallet memory player = players[i];

            assertEq(proxy.getBoutSupporter(boutId, i + 1), player.addr, "bettor address");
            assertEq(proxy.getBoutHiddenBet(boutId, player.addr), 1, "bettor hidden bet");
            assertEq(proxy.getBoutBetAmount(boutId, player.addr), betAmounts[i], "bettor bet amount");
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
        assertEq(proxy.getUserBoutsSupported(player1.addr), 1, "user supported bouts");

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
