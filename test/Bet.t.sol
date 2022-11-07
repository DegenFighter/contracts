// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import { DSTestPlusF, console2 } from "test/utils/DSTestPlusF.sol";

import { Bet, Winner, Pools } from "src/Bet.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

/// @return r random number (sent to server)
/// @return rp obfuscated pick (stored on smart contracts)
function pickFighter(Winner winner, uint256 randomNum) returns (uint256 r, uint256 rp) {
    if (winner == Winner.FighterA) {
        r = randomNum;
        rp = randomNum;
    } else if (winner == Winner.FighterB) {
        r = randomNum;
        rp = randomNum + 1;
    }
}

contract User is Bet {
    Bet bet2;

    constructor(Bet bet) {
        bet2 = Bet(bet);
    }

    /// @dev A user can place a bet
    function placeBet(uint256 boutNum, Winner winner, uint256 amount, uint256 randomNum) public returns (uint256 boutNum_, uint256 r, uint256 rp) {
        (r, rp) = pickFighter(winner, randomNum);
        boutNum_ = bet2.bet(boutNum, amount, rp);
    }

    function placeBetPool(uint256 boutPoolNo, Pools pool, Winner winner, uint256 amount, uint256 randomNum) public returns (uint256 boutPoolNo_, uint256 r, uint256 rp) {
        (r, rp) = pickFighter(winner, randomNum);
        boutPoolNo_ = bet2.betPool(boutPoolNo, pool, amount, rp);
    }
}

contract Server is Bet {
    Bet bet2;

    constructor(Bet bet) {
        bet2 = Bet(bet);
    }

    mapping(uint256 => address[]) S_users; // boutId => users
    mapping(uint256 => uint256[]) S_amounts; // boutId => bet amounts
    mapping(uint256 => uint256[]) S_randno; // boutId => bet amounts

    mapping(uint256 => mapping(Pools => address[])) S_poolUsers; // boutId => pool => users
    mapping(uint256 => mapping(Pools => uint256[])) S_poolAmounts; // boutId => pool => bet amounts
    mapping(uint256 => mapping(Pools => uint256[])) S_poolRandno; // boutId => pool => bet amounts

    function record(uint256 boutNo, address user, uint256 amount, uint256 randno) public {
        S_users[boutNo].push(user);
        S_amounts[boutNo].push(amount);
        S_randno[boutNo].push(randno);
    }

    function recordPool(uint256 boutNo, Pools pool, address user, uint256 amount, uint256 randno) public {
        S_poolUsers[boutNo][pool].push(user);
        S_poolAmounts[boutNo][pool].push(amount);
        S_poolRandno[boutNo][pool].push(randno);
    }

    function revealBets(uint256 boutNo) public {
        uint256 noOfBets = S_users[boutNo].length;
        bet2.reveal(boutNo, S_users[boutNo], S_randno[boutNo], noOfBets);
    }

    function revealPoolBets(uint256 boutNo, Pools pool) public {
        uint256 noOfBets = S_poolUsers[boutNo][pool].length;
        bet2.revealPool(boutNo, pool, S_poolUsers[boutNo][pool], S_poolRandno[boutNo][pool], noOfBets);
    }

    function judgeFight(uint256 boutNo, Winner winner) public {
        bet2.judge(boutNo, winner);
    }

    function judgePoolFight(uint256 boutNo, Pools pool, Winner winner) public {
        bet2.judgePool(boutNo, pool, winner);
    }

    function validateBets(uint256 boutId) public returns (uint256[] memory picks) {}
}

contract BetTest is DSTestPlusF {
    User alice2;
    User bob2;

    Server server;
    Bet bet;

    MockERC20 dfight;
    MockERC20 usdc;

    address alice = address(0xABCD);
    address bob = address(0xBEEF);

    // address server = address(0xEEEEFF);

    address dfTreasury = address(0xDDDDDDAAABBBB);

    function setUp() public {
        bet = new Bet();
        server = new Server(bet);

        alice2 = new User(bet);
        bob2 = new User(bet);

        dfight = new MockERC20("DegenFighter Token", "DFIGHT", 18);
        usdc = new MockERC20("USDC Token", "USDC", 6);

        writeTokenBalance(address(bet), address(this), address(dfight), 100 ether);

        usdc.mint(address(alice2), 100 ether);
        usdc.mint(address(bob2), 100 ether);
        vm.prank(address(alice2));
        usdc.approve(address(bet), 100 ether);
        vm.prank(address(bob2));
        usdc.approve(address(bet), 100 ether);

        vm.label(address(alice2), "ALICE");
        vm.label(address(bob2), "BOB");
        vm.label(address(dfight), "DFIGHT ERC20 contract");
        vm.label(address(usdc), "USDC contract");
        vm.label(address(bet), "Bet contract");
        vm.label(address(server), "SERVER");
        vm.label(address(dfTreasury), "Degen Fighter Treasury");
    }

    function testPrep() public {
        bet.open();
    }

    function testBet() public {
        bet.open();

        bet.setToken(address(dfight));

        uint256 pickR = 100;
        bet.bet(1, 1e18, pickR);
    }

    function testFighterAWins() public {
        (uint256 boutNo, ) = bet.open();

        bet.setToken(address(dfight));
        bet.setTreasury(address(dfTreasury));

        uint256 randno1 = 100;
        (, , uint256 rp) = alice2.placeBet(boutNo, Winner.FighterA, 1 ether, randno1);

        server.record(boutNo, address(alice2), 1 ether, randno1);

        uint256 randno2 = 20001;
        (, , rp) = bob2.placeBet(boutNo, Winner.FighterB, 1 ether, randno2);

        server.record(boutNo, address(bob2), 1 ether, randno2);

        bet.close(boutNo);

        server.revealBets(boutNo);

        server.judgeFight(boutNo, Winner.FighterA);

        vm.prank(address(alice2));
        bet.claim(boutNo);

        vm.prank(address(bob2));
        vm.expectRevert("User picked the losing fighter");
        bet.claim(boutNo);
    }

    function testFighterBWins() public {
        (uint256 boutNo, ) = bet.open();

        bet.setToken(address(dfight));
        bet.setTreasury(address(dfTreasury));

        uint256 randno1 = 100;
        (, , uint256 rp) = alice2.placeBet(boutNo, Winner.FighterA, 1 ether, randno1);

        server.record(boutNo, address(alice2), 1 ether, randno1);

        uint256 randno2 = 20001;
        (, , rp) = bob2.placeBet(boutNo, Winner.FighterB, 1 ether, randno2);

        server.record(boutNo, address(bob2), 1 ether, randno2);

        bet.close(boutNo);

        server.revealBets(boutNo);

        server.judgeFight(boutNo, Winner.FighterB);

        vm.prank(address(alice2));
        vm.expectRevert("User picked the losing fighter");
        bet.claim(boutNo);

        vm.prank(address(bob2));
        bet.claim(boutNo);
    }

    function testPoolFighterAWins() public {
        uint256 boutNo = bet.openPools();

        bet.setToken(address(usdc));
        bet.setTreasury(address(dfTreasury));

        uint256 randno1 = 100;

        console2.log("usdc balance of Bet contract", usdc.balanceOf(address(alice2)));

        vm.prank(address(alice2));
        (, , uint256 rp) = alice2.placeBetPool(boutNo, Pools.Low, Winner.FighterA, 1e6, randno1);

        server.recordPool(boutNo, Pools.Low, address(alice2), 1e6, randno1);

        uint256 randno2 = 20001;
        (, , rp) = bob2.placeBetPool(boutNo, Pools.Low, Winner.FighterB, 1e7, randno2);

        server.recordPool(boutNo, Pools.Low, address(bob2), 1e7, randno2);

        bet.closePools(boutNo);

        server.revealPoolBets(boutNo, Pools.Low);

        console2.log("usdc balance of Bet contract", usdc.balanceOf(address(bet)));

        server.judgePoolFight(boutNo, Pools.Low, Winner.FighterA);
        console2.log("usdc balance of Bet contract", usdc.balanceOf(address(bet)));

        vm.prank(address(alice2));
        bet.claimPool(boutNo, Pools.Low);

        vm.prank(address(bob2));
        vm.expectRevert("User picked the losing fighter");
        bet.claimPool(boutNo, Pools.Low);
    }

    // note currently, when there are no bets placed on the losing fighter, the platform takes no commissions. Is this an issue?
}
