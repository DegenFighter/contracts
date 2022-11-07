// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import { LibERC20 } from "./LibERC20.sol";
import { console2 } from "forge-std/console2.sol";

/// note R = 0 = fighterA, R = 1 = fighterB

enum Winner {
    Undecided,
    FighterA,
    FighterB
}

enum Pools {
    Low,
    Medium,
    High,
    Whale
}

struct BoutInfo {
    bool open;
    bool reveal;
    Winner winner;
    uint256 amountA; // amount bet on fighter A
    uint256 amountB;
}

contract Bet {
    uint256 constant WINNER = 1;
    uint256 constant BASIS_POINTS_100_PERCENT = 10_000;
    uint256 constant POOL_USDC_LOW_MIN = 1e6; // USDC 1e6 == $1.00
    uint256 constant POOL_USDC_LOW_MAX = 1e7;
    uint256 constant POOL_USDC_MED_MIN = 1e7 + 1e6; // $11
    uint256 constant POOL_USDC_MED_MAX = 1e8; // $100
    uint256 constant POOL_USDC_HIGH_MIN = 1e8 + 1e7; // $101
    uint256 constant POOL_USDC_HIGH_MAX = 1e9; // $1000
    uint256 constant POOL_USDC_WHALE_MIN = 1e9 + 1e8; // $1001
    uint256 constant POOL_USDC_WHALE_MAX = 1e10; // $10000

    uint256 revenueBasisPoints = 1_000; // 1000 basis points aka 10%

    address token;
    address dfTreasury;

    uint256 bout;
    uint256 boutPools;

    mapping(uint256 => BoutInfo) bouts; // bout => bout info

    mapping(uint256 => mapping(Pools => BoutInfo)) pools; // boutPools => pool => bout info

    mapping(address => mapping(uint256 => uint256)) picks; // user => bout => R
    mapping(address => mapping(uint256 => uint256)) amounts; // user => bout => bet amount

    mapping(address => mapping(uint256 => mapping(Pools => uint256))) poolPicks; // user => boutPool => pool => R
    mapping(address => mapping(uint256 => mapping(Pools => uint256))) poolAmounts; // user => boutPool => pool => bet amount

    event BoutPrepped(uint256 indexed boutNo);
    event BetPlaced(uint256 indexed boutNo, address indexed user, uint256 indexed amount);
    event BetsRevealed(uint256 indexed boutNo, uint256 amountA, uint256 amountB);
    event BoutJudged(uint256 indexed boutNo, Winner winner);
    event WinClaimed(address user, uint256 boutNo, uint256 amount);

    /// @dev Set the token to be accepted for bets.
    function setToken(address tokenAddress) public {
        token = tokenAddress;
    }

    /// @dev Set the DegenFighter treasury address
    function setTreasury(address treasuryAddress) public {
        dfTreasury = treasuryAddress;
    }

    /// @dev Server opens betting for the next fight
    /// Opens a single bout
    function open() public returns (uint256 boutNo, BoutInfo memory boutInfo) {
        bout++;
        boutNo = bout;
        bouts[boutNo].open = true;

        boutInfo.open = bouts[boutNo].open; // currently redundant

        emit BoutPrepped(boutNo);
    }

    function openPools() public returns (uint256 boutPoolNo) {
        boutPools++;
        boutPoolNo = boutPools;
        pools[boutPoolNo][Pools.Low].open = true;
        pools[boutPoolNo][Pools.Medium].open = true;
        pools[boutPoolNo][Pools.High].open = true;
        pools[boutPoolNo][Pools.Whale].open = true;
    }

    /// @dev Server signs a message that will be used by the user when calling bet()
    function sign(address user, uint256 betPlusR, uint256 fightNo) public {}

    /// @dev User can place a bet
    /// @param pickR The number that can be decoded to represent the better's winning fighter choice
    function bet(uint256 boutNo, uint256 amount, uint256 pickR) public returns (uint256 boutNo_) {
        require(bouts[boutNo].open, "This bout is not open for betting");
        require(amount >= POOL_USDC_LOW_MIN, "Bet size is below minimum");
        // note: currently, a user can only bet once and this is currently checked by seeing if a bet amount has been recorded
        require(amounts[msg.sender][boutNo] == 0, "User has already placed a bet");

        // Store pick R + 1
        picks[msg.sender][boutNo] = pickR;
        amounts[msg.sender][boutNo] = amount;

        boutNo_ = boutNo;
        // Transfer funds to contract
        LibERC20.transfer(token, address(this), amount);

        emit BetPlaced(boutNo, msg.sender, amount);
    }

    function getBet(uint256 boutNo, address user) public returns (uint256 amount) {
        amount = picks[user][boutNo];
    }

    function betPool(uint256 boutPoolNo, Pools pool, uint256 amount, uint256 pickR) public returns (uint256 boutPoolNo_) {
        require(pools[boutPoolNo][pool].open, "This pool is not open for betting");
        if (pool == Pools.Low) {
            require(amount >= POOL_USDC_LOW_MIN && amount <= POOL_USDC_LOW_MAX, "Bet size is out of range for low pool");
        } else if (pool == Pools.Medium) {
            require(amount >= POOL_USDC_MED_MIN && amount <= POOL_USDC_MED_MAX, "Bet size is out of range for med pool");
        } else if (pool == Pools.High) {
            require(amount >= POOL_USDC_HIGH_MIN && amount <= POOL_USDC_HIGH_MAX, "Bet size is out of range for high pool");
        } else if (pool == Pools.Whale) {
            require(amount >= POOL_USDC_WHALE_MIN && amount <= POOL_USDC_WHALE_MAX, "Bet size is out of range for whale pool");
        }

        // Transfer funds to contract
        LibERC20.transferFrom(token, msg.sender, address(this), amount);

        poolPicks[msg.sender][boutPoolNo][pool] = pickR;
        poolAmounts[msg.sender][boutPoolNo][pool] = amount;

        boutPoolNo_ = boutPoolNo;
    }

    /// @dev Close betting
    function close(uint256 boutNo) public returns (uint256 boutNo_) {
        require(bouts[boutNo].open, "Bout already closed");
        // Close bets for this bout
        bouts[boutNo].open = false;
        boutNo_ = boutNo;
    }

    function closePools(uint256 boutPoolNo) public {
        require(pools[boutPoolNo][Pools.Low].open, "Pools are already closed"); // todo okay to just check one if we assume we always open all 4 pools?
        pools[boutPoolNo][Pools.Low].open = false;
        pools[boutPoolNo][Pools.Medium].open = false;
        pools[boutPoolNo][Pools.High].open = false;
        pools[boutPoolNo][Pools.Whale].open = false;
    }

    /// @dev Server calls this to reveal betters picks
    /// betting is closed
    event DebugReveal(uint256 boutNo, uint256 r, uint256 amountAdded, uint256 amountA, uint256 amountB);

    function reveal(uint256 boutNo, address[] memory users, uint256[] memory randno, uint256 noOfBets) public {
        require(!bouts[boutNo].open, "Bout still open");
        require(!bouts[boutNo].reveal, "Bout already revealed");

        bouts[boutNo].reveal = true;

        // uint256 numberOfBets;
        // uint256 numberOfBets = picks.length;

        for (uint256 i; i < noOfBets; i++) {
            picks[users[i]][boutNo] -= randno[i];
            if (picks[users[i]][boutNo] == 0) {
                bouts[boutNo].amountA += amounts[users[i]][boutNo];
            } else if (picks[users[i]][boutNo] == 1) {
                bouts[boutNo].amountB += amounts[users[i]][boutNo];
            }
            emit DebugReveal(boutNo, picks[users[i]][boutNo], amounts[users[i]][boutNo], bouts[boutNo].amountA, bouts[boutNo].amountB);
        }

        emit BetsRevealed(boutNo, bouts[boutNo].amountA, bouts[boutNo].amountB);
    }

    event DebugRevealPool(uint256 boutNo, Pools pool, uint256 r, uint256 amountAdded, uint256 amountA, uint256 amountB);

    function revealPool(uint256 boutNo, Pools pool, address[] memory users, uint256[] memory randno, uint256 noOfBets) public {
        require(!pools[boutNo][pool].open, "Bout pool still open");
        require(!pools[boutNo][pool].reveal, "Bout pool already revealed");

        pools[boutNo][pool].reveal = true;

        for (uint256 i; i < noOfBets; i++) {
            poolPicks[users[i]][boutNo][pool] -= randno[i];
            if (poolPicks[users[i]][boutNo][pool] == 0) {
                pools[boutNo][pool].amountA += poolAmounts[users[i]][boutNo][pool];
            } else if (poolPicks[users[i]][boutNo][pool] == 1) {
                pools[boutNo][pool].amountB += poolAmounts[users[i]][boutNo][pool];
            }
            emit DebugRevealPool(boutNo, pool, poolPicks[users[i]][boutNo][pool], poolAmounts[users[i]][boutNo][pool], pools[boutNo][pool].amountA, pools[boutNo][pool].amountB);
        }
    }

    /// @dev Server determines winner of bout and records on chain.
    function judge(uint256 boutNo, Winner winner) public {
        // Picks for this bout must be revealed before judgement
        require(bouts[boutNo].reveal, "Picks for this bout are not yet revealed");

        bouts[boutNo].winner = winner;

        uint256 amountBetOnLoser;

        if (winner == Winner.FighterA) {
            amountBetOnLoser = bouts[boutNo].amountB;
        } else if (winner == Winner.FighterB) {
            amountBetOnLoser = bouts[boutNo].amountA;
        }

        // Transfer platform revenue to DegenFighter treasury EOA/contract
        uint256 amountForDegenFighterTreasury = (amountBetOnLoser * revenueBasisPoints) / BASIS_POINTS_100_PERCENT;
        if (amountForDegenFighterTreasury > 0) {
            LibERC20.transfer(token, address(dfTreasury), amountForDegenFighterTreasury);
        }

        emit BoutJudged(boutNo, winner);
    }

    function judgePool(uint256 boutNo, Pools pool, Winner winner) public {
        // Picks for this bout must be revealed before judgement
        require(pools[boutNo][pool].reveal, "Picks for this bout are not yet revealed");

        pools[boutNo][pool].winner = winner;

        uint256 amountBetOnLoser;

        if (winner == Winner.FighterA) {
            amountBetOnLoser = pools[boutNo][pool].amountB;
        } else if (winner == Winner.FighterB) {
            amountBetOnLoser = pools[boutNo][pool].amountA;
        }

        // Transfer platform revenue to DegenFighter treasury EOA/contract
        uint256 amountForDegenFighterTreasury = (amountBetOnLoser * revenueBasisPoints) / BASIS_POINTS_100_PERCENT;
        if (amountForDegenFighterTreasury > 0) {
            LibERC20.transfer(token, address(dfTreasury), amountForDegenFighterTreasury);
        }
    }

    function outcome(uint256 boutNo, address user) public returns (bool correct) {
        if (picks[user][boutNo] == 0 && bouts[boutNo].winner == Winner.FighterA) {
            correct = true;
        } else if (picks[user][boutNo] == 1 && bouts[boutNo].winner == Winner.FighterB) {
            correct = true;
        }
    }

    function poolOutcome(uint256 boutNo, Pools pool, address user) public returns (bool correct) {
        if (poolPicks[user][boutNo][pool] == 0 && pools[boutNo][pool].winner == Winner.FighterA) {
            correct = true;
        } else if (poolPicks[user][boutNo][pool] == 1 && pools[boutNo][pool].winner == Winner.FighterB) {
            correct = true;
        }
    }

    /// @dev Claim wins from a bout
    function claim(uint256 boutNo) public returns (uint256 userPayout) {
        // Bout must be closed
        require(!bouts[boutNo].open, "This bout is not open for betting");

        // Picks for this bout must be revealed
        require(bouts[boutNo].reveal, "Picks for this bout are not yet revealed");

        require(outcome(boutNo, msg.sender), "User picked the losing fighter");

        require(amounts[msg.sender][boutNo] != 0, "User's bet amount must be greater than 0");

        // The amount that the user bet in the bout
        uint256 amount = amounts[msg.sender][boutNo];

        uint256 amountBetOnWinner;
        uint256 amountBetOnLoser;

        if (bouts[boutNo].winner == Winner.FighterA) {
            amountBetOnWinner = bouts[boutNo].amountA;
            amountBetOnLoser = bouts[boutNo].amountB;
        } else if (bouts[boutNo].winner == Winner.FighterB) {
            amountBetOnWinner = bouts[boutNo].amountB;
            amountBetOnLoser = bouts[boutNo].amountA;
        }
        // amount bet on winner by user / total amount bet on winner * total amount bet (aka amount bet on winner and loser)

        uint256 totalAmount = amountBetOnWinner + amountBetOnLoser;

        uint256 amountForDegenFighterTreasury = (amountBetOnLoser * revenueBasisPoints) / BASIS_POINTS_100_PERCENT;

        userPayout = (amount * (totalAmount - amountForDegenFighterTreasury)) / amountBetOnWinner; // todo check math

        LibERC20.transfer(token, address(msg.sender), userPayout);

        emit WinClaimed(msg.sender, boutNo, userPayout);
    }

    function claimPool(uint256 boutNo, Pools pool) public returns (uint256 userPayout) {
        // Bout must be closed
        require(!pools[boutNo][pool].open, "This bout is not open for betting");

        // Picks for this bout must be revealed
        require(pools[boutNo][pool].reveal, "Picks for this bout are not yet revealed");

        require(poolOutcome(boutNo, pool, msg.sender), "User picked the losing fighter");

        require(poolAmounts[msg.sender][boutNo][pool] != 0, "User's bet amount must be greater than 0");

        // The amount that the user bet in the bout
        uint256 amount = poolAmounts[msg.sender][boutNo][pool];

        uint256 amountBetOnWinner;
        uint256 amountBetOnLoser;

        if (pools[boutNo][pool].winner == Winner.FighterA) {
            amountBetOnWinner = pools[boutNo][pool].amountA;
            amountBetOnLoser = pools[boutNo][pool].amountB;
        } else if (pools[boutNo][pool].winner == Winner.FighterB) {
            amountBetOnWinner = pools[boutNo][pool].amountB;
            amountBetOnLoser = pools[boutNo][pool].amountA;
        }
        // amount bet on winner by user / total amount bet on winner * total amount bet (aka amount bet on winner and loser)

        uint256 totalAmount = amountBetOnWinner + amountBetOnLoser;

        uint256 amountForDegenFighterTreasury = (amountBetOnLoser * revenueBasisPoints) / BASIS_POINTS_100_PERCENT;

        userPayout = (amount * (totalAmount - amountForDegenFighterTreasury)) / amountBetOnWinner; // todo check math

        LibERC20.transfer(token, address(msg.sender), userPayout);
    }
}
