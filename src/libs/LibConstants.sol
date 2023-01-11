// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

library LibConstants {
    bytes32 public constant EIP712_DOMAIN_HASH = keccak256("EIP712_DOMAIN_HASH");

    bytes32 public constant MEME_TOKEN_ADDRESS = keccak256("MEME_TOKEN_ADDRESS");
    bytes32 public constant SERVER_ADDRESS = keccak256("SERVER_ADDRESS");

    uint public constant MIN_BET_AMOUNT = 10 ether;

    uint public constant TOKEN_MEME = 1;
}
