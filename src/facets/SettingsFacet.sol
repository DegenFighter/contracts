// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { AppStorage, LibAppStorage } from "../Objects.sol";
import { ISettingsFacet } from "../interfaces/ISettingsFacet.sol";
import { FacetBase } from "../FacetBase.sol";
import { LibConstants } from "src/libs/LibConstants.sol";

contract SettingsFacet is FacetBase, ISettingsFacet {
    constructor() FacetBase() {}

    function getAddress(bytes32 key) external view returns (address) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.addresses[key];
    }

    function setAddress(bytes32 key, address value) external isAdmin {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.addresses[key] = value;
    }

    function setPriceOracle(address priceOracle) external isAdmin {
        require(priceOracle != address(0), "price oracle cannot be address(0)");
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.priceOracle = priceOracle;
    }

    function setTwapInterval(uint32 twapInterval) external isAdmin {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.twapInterval = twapInterval;
    }

    function setCurrency(address currencyAddress) external isAdmin {
        require(currencyAddress != address(0), "currency address cannot be address(0)");
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.currencyAddress = currencyAddress;
    }

    function setTreasuryAddress(address treasuryAddress) external isAdmin {
        require(treasuryAddress != address(0), "treasury address cannot be address(0)");
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.addresses[LibConstants.TREASURY_ADDRESS] = treasuryAddress;
    }
}
