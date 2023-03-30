// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

enum BoutState {
    Uninitialized,
    Created,
    Ended,
    Expired
}

enum BoutFighter {
    Invalid,
    FighterA,
    FighterB
}

enum MemeBuySizeDollars {
    Five,
    Ten,
    Twenty,
    Fifty,
    Hundred
}

/**
 * @dev A bet.
 */
struct BetInfo {
    uint8 hidden;
    BoutFighter revealed; // we will never actually use this storage slot, but when returning in an external call this will be set
    uint amount;
    bool winningsClaimed;
}

/**
 * @dev A bout.
 */
struct Bout {
    uint numBettors;
    uint totalPot;
    uint endTime;
    uint expiryTime;
    BoutState state;
    BoutFighter winner;
    uint8[] revealValues; // the 'r' values packed into 2 bits each
    uint winningsRatio;
    mapping(uint => address) bettors;
    mapping(address => uint) bettorIndexes;
    mapping(address => BetInfo) bets;
    mapping(BoutFighter => uint) fighterIds;
    mapping(BoutFighter => uint) fighterPotBalances;
}

/**
 * @dev Same as Bout, except with mapping fields removed.
 *
 * This is used to return Bout data from external calls.
 */
struct BoutNonMappingInfo {
    uint numBettors;
    uint totalPot;
    uint expiryTime;
    uint endTime;
    BoutState state;
    BoutFighter winner;
    uint8[] revealValues; // the 'r' values packed into 2 bits each
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

// Linked list node to keep track of bouts
struct BoutListNode {
    // id of bout
    uint boutId;
    // id of previous node in list
    uint prev;
    // id of next node in list
    uint next;
}

// Linked list to keep track of bouts
struct BoutList {
    // node id => node item
    mapping(uint => BoutListNode) nodes;
    // id of first node in list
    uint head;
    // id of last node in list
    uint tail;
    // length of list
    uint len;
    // id of next node to be added
    uint nextId;
}

struct AppStorage {
    bool diamondInitialized;
    uint256 reentrancyStatus;
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

    // token id => wallet => balance
    mapping(uint => mapping(address => uint)) tokenBalances;
    // token id => supply
    mapping(uint => uint) tokenSupply;
    ///
    /// Fights
    ///

    // no. of bouts created
    uint totalBouts;
    // bout id => bout details
    mapping(uint => Bout) bouts;
    // bout index => bout id
    mapping(uint => uint) boutIdByIndex;
    ///
    /// Fight bettors
    ///

    // wallet => no. of bouts supported
    mapping(address => uint) userTotalBoutsBetOn;
    // wallet => linked list of bouts where winnings still need to be claimed
    mapping(address => BoutList) userBoutsWinningsToClaimList;
    // wallet => list of bouts supported
    mapping(address => mapping(uint => uint)) userBoutsBetOnByIndex;
    // tokenId => is this an item being sold by DegenFighter?
    mapping(uint256 => bool) itemForSale;
    // tokenId => cost of item in MEMEs
    mapping(uint256 => uint256) costOfItem;
    ///
    /// ERC2771 meta transactions
    ///
    address trustedForwarder;
    ///
    /// Uniswap
    ///
    address priceOracle;
    uint32 twapInterval;
    // the ERC20 address that is accepted to purchase MEME tokens
    address currencyAddress;
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
