// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "script/utils/DeploymentHelpers.sol";
import { Proxy } from "src/Proxy.sol";
import { IProxy } from "src/interfaces/IProxy.sol";
import { MemeToken } from "src/MemeToken.sol";
import { LibConstants } from "src/libs/LibConstants.sol";

contract SmartDeploy is DeploymentHelpers {
    function smartDeploy(
        bool deployNewDiamond,
        bool initNewDiamond,
        FacetDeploymentAction facetDeploymentAction,
        string[] memory facetsToCutIn
    )
        external
        returns (
            // string[] memory facetsToCutIn
            address diamondAddress,
            address initDiamondAddress
        )
    {
        vm.startBroadcast(msg.sender);

        // deploy proxy
        (diamondAddress, initDiamondAddress) = smartDeployment(deployNewDiamond, initNewDiamond, facetDeploymentAction, facetsToCutIn);
        console.log("Address[proxy]: ", diamondAddress);
        IProxy proxy = IProxy(diamondAddress);

        // deploy token
        address memeTokenAddress = address(new MemeToken(diamondAddress));
        console.log("Address[memeToken]: ", memeTokenAddress);
        proxy.setAddress(LibConstants.MEME_TOKEN_ADDRESS, memeTokenAddress);

        // set server address
        proxy.setAddress(LibConstants.SERVER_ADDRESS, 0x5eD6EaEAA19A5945f403806292Dc7913B86EA429);

        vm.stopBroadcast();
    }
}
