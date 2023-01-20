// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

library LibConstants {
    bytes32 internal constant EIP712_DOMAIN_HASH = keccak256("EIP712_DOMAIN_HASH");

    bytes32 internal constant MEME_TOKEN_ADDRESS = keccak256("MEME_TOKEN_ADDRESS");
    bytes32 internal constant SERVER_ADDRESS = keccak256("SERVER_ADDRESS");
    bytes32 internal constant TREASURY_ADDRESS = keccak256("TREASURY_ADDRESS");

    uint internal constant MIN_BET_AMOUNT = 10 ether;

    uint internal constant TOKEN_MEME = 1;

    address internal constant WMATIC_POLYGON_ADDRESS = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
}

library LibTokenIds {
    uint256 internal constant TOKEN_MEME = 1;
    uint256 internal constant BROADCAST_MSG = 2;
    uint256 internal constant SUPPORTER_INFLUENCE = 3;
}
