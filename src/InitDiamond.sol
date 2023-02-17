// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { AppStorage, LibAppStorage } from "src/Objects.sol";
import { LibConstants } from "./libs/LibConstants.sol";
import { LibTokenIds } from "./libs/LibToken.sol";
import { LibDiamond } from "lib/diamond-2-hardhat/contracts/libraries/LibDiamond.sol";
import { LibEip712 } from "src/libs/LibEip712.sol";
import { IDiamondCut } from "lib/diamond-2-hardhat/contracts/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "lib/diamond-2-hardhat/contracts/interfaces/IDiamondLoupe.sol";
import { IERC165 } from "lib/diamond-2-hardhat/contracts/interfaces/IERC165.sol";
import { IERC173 } from "lib/diamond-2-hardhat/contracts/interfaces/IERC173.sol";

error DiamondAlreadyInitialized();

contract InitDiamond {
    event InitializeDiamond(address sender);

    function initialize() external {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (s.diamondInitialized) {
            revert DiamondAlreadyInitialized();
        }

        // items for sale
        s.itemForSale[LibTokenIds.BROADCAST_MSG] = true;
        s.itemForSale[LibTokenIds.SUPPORTER_INFLUENCE] = true;

        // set prices of items
        s.costOfItem[LibTokenIds.BROADCAST_MSG] = 100e18;
        s.costOfItem[LibTokenIds.SUPPORTER_INFLUENCE] = 300e18;

        s.priceOracle = 0xA374094527e1673A86dE625aa59517c5dE346d32; // polygon wmatic-usdc fee=500
        s.currencyAddress = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

        // adding ERC165 data
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;

        s.diamondInitialized = true;
        emit InitializeDiamond(msg.sender);
    }
}
