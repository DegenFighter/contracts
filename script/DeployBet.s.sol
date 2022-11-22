// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "src/Bet.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

contract DeployBet is Script {
    MockERC20 test;

    function setUp() public {}

    function run() public {
        vm.broadcast();
        address betAddress = address(new Bet());
        string memory deployFile = "deployedAddresses.json";

        // test = new MockERC20("Test", "TEST", 18);
        vm.removeFile(deployFile);
        vm.writeLine(deployFile, '{ "Bet": { ');

        string memory d = string.concat('"', vm.toString(block.chainid), '": { "address": "', vm.toString(betAddress), '" }}} ');
        vm.writeLine(deployFile, d);
    }
}
