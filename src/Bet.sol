// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import { LibERC20 } from "./LibERC20.sol";

// import { console2 } from "forge-std/console2.sol";

/// Naming conventions for the Betting Platform
/// pr: pick plus R, where pick is 0 or 1
/// note pick = 0 = fighterA, pick = 1 = fighterB

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

error PermitDeadlineExpired(uint256 deadline, uint256 blockTimeStamp);
error InvalidSigner(address recoveredAddress, address expectedSignerAddress);
error BoutClosed();

contract Bet {
    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    address owner;

    mapping(address => uint256) public nonces;

    constructor() {
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    uint256 constant WINNER = 1;
    uint256 constant BASIS_POINTS_100_PERCENT = 10_000;
    uint256 constant POOL_USDC_LOW_MIN = 1e6; // USDC 1e6 == $1.00
    uint256 constant POOL_USDC_LOW_MAX = 1e7;
    uint256 constant POOL_USDC_MED_MIN = 1e7 + 1e6; // $11
    uint256 constant POOL_USDC_MED_MAX = 1e8; // $100
    uint256 constant POOL_USDC_HIGH_MIN = 1e8 + 1e6; // $101
    uint256 constant POOL_USDC_HIGH_MAX = 1e9; // $1000
    uint256 constant POOL_USDC_WHALE_MIN = 1e9 + 1e6; // $1001
    uint256 constant POOL_USDC_WHALE_MAX = 1e10; // $10000

    uint256 revenueBasisPoints = 1_000; // 1000 basis points aka 10%

    address token;
    address dfTreasury;

    uint256 bout;

    mapping(uint256 => BoutInfo) bouts; // bout => bout info
    mapping(uint256 => uint256) numUniqueBets; // bout => number of unique users that bet on this bout

    mapping(address => mapping(uint256 => uint256)) usersBoutMapIndex; // user => bout => pick index in bitmap
    mapping(uint256 => mapping(uint256 => address)) indexedUsers; // bout => pick index in bitmap => user
    mapping(uint256 => mapping(uint256 => uint256)) picksB; // bout => bucket => pick bitmap
    uint256 constant mask = 3; // todo
    mapping(address => mapping(uint256 => uint256)) picks; // user => bout => R
    mapping(address => mapping(uint256 => uint256)) amounts; // user => bout => bet amount

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

    /// @dev Server signs a message that will be used by the user when calling bet()
    function sign(address server, address user, uint256 pr, uint256 bout, uint256 nonce, uint256 deadline) public {}

    function permitBet(uint256 boutNo, uint256 amount, uint256 pr, address server, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public returns (uint256) {
        if (deadline < block.timestamp) revert PermitDeadlineExpired(deadline, block.timestamp);
        // require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // address user = msg.sender;
        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256("Sign(address server,address user,uint256 pr,uint256 bout,uint256 nonce,uint256 deadline)"),
                                server,
                                msg.sender,
                                pr,
                                boutNo,
                                nonces[server]++, //todo update this
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            if (recoveredAddress == address(0) || recoveredAddress != server) revert InvalidSigner(recoveredAddress, server);
            // require(recoveredAddress != address(0) && recoveredAddress == server, "INVALID_SIGNER");
        }

        return bet(boutNo, amount, pr);
        // return betPacked(boutNo, amount, pr);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    string name = "Bet Contract v1";

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    // todo change to internal / deprecated and replaced by permitBet()
    /// @dev User can place a bet
    /// @param pr The number that can be decoded to represent the better's winning fighter choice
    function bet(uint256 boutNo, uint256 amount, uint256 pr) public returns (uint256 boutNo_) {
        require(bouts[boutNo].open, "This bout is not open for betting");
        require(amount >= POOL_USDC_LOW_MIN, "Bet size is below minimum");
        // note: currently, a user can only bet once and this is currently checked by seeing if a bet amount has been recorded
        require(amounts[msg.sender][boutNo] == 0, "User has already placed a bet");

        // Store pick + R
        picks[msg.sender][boutNo] = pr;
        amounts[msg.sender][boutNo] = amount;

        boutNo_ = boutNo;
        // Transfer funds to contract
        LibERC20.transfer(token, address(this), amount);

        emit BetPlaced(boutNo, msg.sender, amount);
    }

    function setPr(uint256 boutNo, uint256 index, uint256 pr) public returns (uint256 map_) {
        uint256 bucket = index >> 7;
        // move pr to position based on index
        uint256 movePr = pr << (2 * (index & 0x7f));

        picksB[boutNo][bucket] |= movePr;
    }

    function getPr(uint256 boutNo, uint256 index) public returns (uint256 pr) {
        uint256 bucket = index >> 7;

        pr = (picksB[boutNo][bucket] >> (2 * (index & 0x7f))) & mask;
    }

    function betPacked(uint256 boutNo, uint256 amount, uint256 pr) private returns (uint256 boutNo_) {
        require(bouts[boutNo].open, "This bout is not open for betting");
        require(amount >= POOL_USDC_LOW_MIN, "Bet size is below minimum");
        // note: currently, a user can only bet once and this is currently checked by seeing if a bet amount has been recorded
        // todo change this check
        require(amounts[msg.sender][boutNo] == 0, "User has already placed a bet");

        // todo need additional checks here to ensure first time better on bout
        // note Index for a user starts at 0.
        uint256 userBoutIndex = numUniqueBets[boutNo];
        numUniqueBets[boutNo]++;
        usersBoutMapIndex[msg.sender][boutNo] = userBoutIndex;
        indexedUsers[boutNo][userBoutIndex] = msg.sender;
        // Store pick + R
        setPr(boutNo, usersBoutMapIndex[msg.sender][boutNo], pr);
        amounts[msg.sender][boutNo] = amount;

        boutNo_ = boutNo;
        // Transfer funds to contract
        LibERC20.transfer(token, address(this), amount);

        emit BetPlaced(boutNo, msg.sender, amount);
    }

    function getBet(uint256 boutNo, address user) public returns (uint256 amount) {
        amount = picks[user][boutNo];
    }

    /// @dev Close betting
    function close(uint256 boutNo) public returns (uint256 boutNo_) {
        require(bouts[boutNo].open, "Bout already closed");
        // Close bets for this bout
        bouts[boutNo].open = false;
        boutNo_ = boutNo;
    }

    /// @dev Server calls this to reveal betters picks
    /// betting is closed
    event DebugReveal(uint256 boutNo, uint256 r, uint256 amountAdded, uint256 amountA, uint256 amountB);

    function reveal(uint256 boutNo, address[] memory users, uint256[] memory randno, uint256 noOfBets) public {
        require(!bouts[boutNo].open, "Bout still open");
        require(!bouts[boutNo].reveal, "Bout already revealed");

        bouts[boutNo].reveal = true;

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

    function readMap(uint256 prMap, uint256 index) private returns (uint256 pr) {
        pr = (prMap >> (2 * (index & 0x7f))) & mask;
    }

    function revealPacked(uint256 boutNo, uint256[] memory prPacked) public {
        require(!bouts[boutNo].open, "Bout still open");
        require(!bouts[boutNo].reveal, "Bout already revealed");

        bouts[boutNo].reveal = true;

        uint256 noOfBets = numUniqueBets[boutNo]; // aka max index of boutNo
        uint256 noOfBuckets = noOfBets >> 7;

        uint256 r;
        uint256 userPr;
        for (uint256 bucketNo; bucketNo < noOfBuckets; bucketNo++) {
            for (uint256 index; index < noOfBets; index++) {
                // note: Server passes in r = 0 if the bet is invalid.
                // todo deal with r = 0
                // todo store pick
                r = readMap(prPacked[bucketNo], index);

                userPr = getPr(boutNo, index);

                if (userPr - r == 0) {
                    bouts[boutNo].amountA += amounts[indexedUsers[boutNo][index]][boutNo];
                } else if (userPr - r == 1) {
                    bouts[boutNo].amountB += amounts[indexedUsers[boutNo][index]][boutNo];
                }
                emit DebugReveal(boutNo, userPr - r, amounts[indexedUsers[boutNo][index]][boutNo], bouts[boutNo].amountA, bouts[boutNo].amountB);
            }
        }

        emit BetsRevealed(boutNo, bouts[boutNo].amountA, bouts[boutNo].amountB);
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

    function outcome(uint256 boutNo, address user) public returns (bool correct) {
        if (picks[user][boutNo] == 0 && bouts[boutNo].winner == Winner.FighterA) {
            correct = true;
        } else if (picks[user][boutNo] == 1 && bouts[boutNo].winner == Winner.FighterB) {
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
}
