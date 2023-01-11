// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

enum BoutState {
    Created,
    SupportRevealed,
    Ended
}

enum BoutParticipant {
    Unknown,
    FighterA,
    FighterB
}

struct Bout {
    uint id;
    BoutState state;
    uint numSupporters;
    mapping(uint => address) supporters;
    mapping(address => uint8) hiddenBets;
    uint numRevealedBets;
    mapping(address => BoutParticipant) revealedBets;
    mapping(address => uint) betAmounts;
    mapping(BoutParticipant => uint) fighterIds;
    mapping(BoutParticipant => uint) fighterPots;
    mapping(BoutParticipant => uint) fighterPotBalances;
    uint totalPot;
    uint revealTime;
    uint endTime;
    BoutParticipant winner;
    BoutParticipant loser;
}

/**
 * @dev Same as Bout, except with mapping fields removed.
 *
 * This is used to return Bout data from external calls.
 */
struct BoutNonMappingInfo {
    uint id;
    BoutState state;
    uint numSupporters;
    uint numRevealedBets;
    uint totalPot;
    uint revealTime;
    uint endTime;
    BoutParticipant winner;
    BoutParticipant loser;
}

// from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/EIP712.sol
struct EIP712 {
    bytes32 CACHED_DOMAIN_SEPARATOR;
    uint256 CACHED_CHAIN_ID;
    address CACHED_THIS;
    bytes32 HASHED_NAME;
    bytes32 HASHED_VERSION;
    bytes32 TYPE_HASH;
}

struct AppStorage {
    ///
    /// EIP712
    ///

    // eip712 data
    EIP712 eip712;
    ///
    /// Settings
    ///

    mapping(bytes32 => address) addresses;
    mapping(bytes32 => bytes32) bytes32s;
    ///
    /// MEME token
    ///

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
