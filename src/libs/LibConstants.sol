// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

library LibConstants {
    // EIP712 domain name
    bytes32 internal constant EIP712_DOMAIN_HASH = keccak256("EIP712_DOMAIN_HASH");
    // address of MEME token contract
    bytes32 internal constant MEME_TOKEN_ADDRESS = keccak256("MEME_TOKEN_ADDRESS");
    // wallet address of the server
    bytes32 internal constant SERVER_ADDRESS = keccak256("SERVER_ADDRESS");
    // wallet address of the treasury
    bytes32 internal constant TREASURY_ADDRESS = keccak256("TREASURY_ADDRESS");
    // the minimum amount of tokens that can be bet on a bout
    uint internal constant MIN_BET_AMOUNT = 10 ether;
    // time before a bout expires unless it is finalized
    uint internal constant DEFAULT_BOUT_EXPIRATION_TIME = 1 days;
    // address of the WMATIC token contract on Polygon mainnet
    address internal constant WMATIC_POLYGON_ADDRESS = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
}
