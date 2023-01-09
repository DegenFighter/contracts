// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { LibDiamond } from "lib/diamond-2-hardhat/contracts/libraries/LibDiamond.sol";
import { AppStorage, LibAppStorage } from "./Base.sol";
import { LibConstants } from "./libs/LibConstants.sol";

abstract contract Modifiers {
    modifier isAdmin() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    modifier isServer() {
        AppStorage storage s = LibAppStorage.diamondStorage();
        require(msg.sender == s.addresses[LibConstants.SERVER_ADDRESS], "Not server");
        _;
    }
}
