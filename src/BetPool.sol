// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./Bet.sol";

contract BetPool is Bet {
    mapping(uint256 => mapping(Pools => BoutInfo)) pools; // boutPools => pool => bout info

    mapping(address => mapping(uint256 => mapping(Pools => uint256))) poolPicks; // user => boutPool => pool => R
    mapping(address => mapping(uint256 => mapping(Pools => uint256))) poolAmounts; // user => boutPool => pool => bet amount

    function openPools() public returns (uint256 boutPoolNo) {
        boutPools++;
        boutPoolNo = boutPools;
        pools[boutPoolNo][Pools.Low].open = true;
        pools[boutPoolNo][Pools.Medium].open = true;
        pools[boutPoolNo][Pools.High].open = true;
        pools[boutPoolNo][Pools.Whale].open = true;
    }

    function betPool(uint256 boutPoolNo, Pools pool, uint256 amount, uint256 pr) public returns (uint256 boutPoolNo_) {
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

        poolPicks[msg.sender][boutPoolNo][pool] = pr;
        poolAmounts[msg.sender][boutPoolNo][pool] = amount;

        boutPoolNo_ = boutPoolNo;
    }

    function closePools(uint256 boutPoolNo) public {
        require(pools[boutPoolNo][Pools.Low].open, "Pools are already closed"); // todo okay to just check one if we assume we always open all 4 pools?
        pools[boutPoolNo][Pools.Low].open = false;
        pools[boutPoolNo][Pools.Medium].open = false;
        pools[boutPoolNo][Pools.High].open = false;
        pools[boutPoolNo][Pools.Whale].open = false;
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

    function poolOutcome(uint256 boutNo, Pools pool, address user) public returns (bool correct) {
        if (poolPicks[user][boutNo][pool] == 0 && pools[boutNo][pool].winner == Winner.FighterA) {
            correct = true;
        } else if (poolPicks[user][boutNo][pool] == 1 && pools[boutNo][pool].winner == Winner.FighterB) {
            correct = true;
        }
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
