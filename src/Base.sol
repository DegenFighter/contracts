// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

enum BoutState {
    Open,
    SupportClosed,
    Ended
}

enum BoutTarget {
    Unknown,
    FighterA,
    FighterB
}

struct Bout {
    uint num;
    BoutState state;
    mapping(BoutTarget => uint) fighters;
    mapping(BoutTarget => uint) pots;
    uint revealTime;
    uint endTime;
    BoutTarget winner;
}

struct AppStorage {
    ///
    /// MEME token
    ///

    // MEME token address
    address memeToken;
    // minimum balance that's mintable
    uint memeMintableBalance;
    // wallet => MEME balance
    mapping(address => uint) memeBalance;
    // MEME supply
    uint memeSupply;
    ///
    /// Fights
    ///

    // no. of bouts created
    uint totalBouts;
    // no. of bouts finished
    uint boutsFinished;
    // bout => details
    mapping(uint => Bout) bouts;
    // wallet => bout => bet amounts
    mapping(address => mapping(uint => uint)) boutBetAmounts;
    // wallet => bout => bet targetr
    mapping(address => mapping(uint => BoutTarget)) boutBetTargets;
    // wallet => bout
    mapping(address => uint) lastClaimedWinnings;
}

library LibAppStorage {
    bytes32 internal constant DIAMOND_APP_STORAGE_POSITION = keccak256("diamond.app.storage");

    function diamondStorage() internal pure returns (AppStorage storage ds) {
        bytes32 position = DIAMOND_APP_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}
