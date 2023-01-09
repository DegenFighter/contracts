// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

library LibConstants {
    bytes32 public constant MEME_TOKEN_ADDRESS = keccak256("MEME_TOKEN_ADDRESS");
    bytes32 public constant SERVER_ADDRESS = keccak256("SERVER_ADDRESS");
    bytes32 public constant EIP712_DOMAIN_HASH = keccak256("EIP712_DOMAIN_HASH");
    uint public constant MIN_SUPPORT_AMOUNT = 10 ether;
}
