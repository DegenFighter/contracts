// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

enum BoutState {
    Uninitialized,
    Finalized
}

enum BoutFighter {
    FighterA, // 0
    FighterB // 1
}

enum MemeBuySizeDollars {
    Five,
    Ten,
    Twenty,
    Fifty,
    Hundred
}

struct Bout {
    uint totalPot;
    uint finalizeTime;
    BoutState state;
    BoutFighter winner;
    BoutFighter loser;
    uint[] fighterNumBettors;
    uint[] fighterIds;
    uint[] fighterPots;
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
    /// Users
    ///

    // total bets made by user
    mapping(address => uint) userTotalBetsMade;
    // total amount bet by user
    mapping(address => uint) userTotalAmountBet;
    // total bets won by user
    mapping(address => uint) userTotalBetsWon;
    // total amount won by user
    mapping(address => uint) userTotalAmountWon;
    ///
    /// Fights
    ///

    // no. of bouts created
    uint totalBouts;
    // no. of bouts finalized
    uint finalizedBouts;
    // bout id => bout details
    mapping(uint => Bout) bouts;
    // bout index => bout id
    mapping(uint => uint) boutIdByIndex;
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
