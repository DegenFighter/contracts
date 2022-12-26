// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

enum BoutState {
    Created,
    SupportRevealed,
    Ended
}

enum BoutTarget {
    Unknown,
    FighterA,
    FighterB
}

struct Bout {
    uint id;
    BoutState state;
    mapping(BoutTarget => uint) fighters;
    mapping(BoutTarget => uint) potTotals;
    mapping(BoutTarget => uint) potBalances;
    uint revealTime;
    uint endTime;
    BoutTarget winner;
    BoutTarget loser;
}

struct AppStorage {
    ///
    /// Settings
    ///

    // addresses
    mapping(bytes32 => address) addresses;
    ///
    /// MEME token
    ///

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
    ///
    /// Fight supporters
    ///

    // wallet => bout num => support amount (MEME)
    mapping(address => mapping(uint => uint)) userBoutSupportAmounts;
    // wallet => bout num => support target fighter
    mapping(address => mapping(uint => BoutTarget)) userBoutSupportTargets;
    // wallet => no. of bouts supported
    mapping(address => uint) userBoutsSupported;
    // wallet => no. of bouts where winnings claimed
    mapping(address => uint) userBoutsClaimed;
    // wallet => list of bouts supported
    mapping(address => mapping(uint => uint)) userBoutSupportList;
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
