// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "src/Proxy.sol";

contract DeployProxy is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
        address proxyAddress = address(new Proxy(msg.sender));
        string memory deployFile = "deployedAddresses.json";

        // test = new MockERC20("Test", "TEST", 18);
        vm.removeFile(deployFile);
        vm.writeLine(deployFile, '{ "Proxy": { ');

        string memory d = string.concat('"', vm.toString(block.chainid), '": { "address": "', vm.toString(proxyAddress), '" }}} ');
        vm.writeLine(deployFile, d);
    }
}
