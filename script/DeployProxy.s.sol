// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Script.sol";

import { Proxy } from "src/Proxy.sol";
import { IProxy } from "src/IProxy.sol";
import { MemeToken } from "src/MemeToken.sol";
import { LibGeneratedFacetHelpers } from "./generated/LibGeneratedFacetHelpers.sol";

contract DeployProxy is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();

        // deploy proxy
        Proxy proxy = new Proxy(address(this));
        address proxyAddress = address(proxy);
        LibGeneratedFacetHelpers.deployAndCutFacets(proxyAddress);

        address memeToken = address(new MemeToken(proxyAddress));
        IProxy(proxyAddress).setMemeToken(memeToken);

        IProxy(proxyAddress).transferOwnership(msg.sender);
    }
}
