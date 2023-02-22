// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import "src/ChainDependentData.sol";
import { IProxy } from "src/interfaces/IProxy.sol";
import { DeploymentHelpers } from "script/utils/DeploymentHelpers.sol";

contract UpdateParams is Script, DeploymentHelpers {
    function setUp() public {}

    function run() public {
        (address diamondAddress, ) = getDiamondAddressesFromFile();
        IProxy proxy = IProxy(diamondAddress);

        ChainDependent memory data = returnChainDependentData();

        vm.startBroadcast();

        proxy.setTwapParams(data.priceOracle, 0, data.currencyAddress);

        vm.stopBroadcast();
    }
}
