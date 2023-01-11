// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { AppStorage, LibAppStorage } from "../Base.sol";
import { ISettingsFacet } from "../interfaces/ISettingsFacet.sol";
import { Modifiers } from "../Modifiers.sol";

contract SettingsFacet is ISettingsFacet, Modifiers {
    function getAddress(bytes32 key) external view returns (address) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.addresses[key];
    }

    function setAddress(bytes32 key, address value) external isAdmin {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.addresses[key] = value;
    }
}
