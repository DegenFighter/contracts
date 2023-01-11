// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { ERC2771Context } from "lib/openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import { LibDiamond } from "lib/diamond-2-hardhat/contracts/libraries/LibDiamond.sol";

import { CallerMustBeAdminError, CallerMustBeServerError } from "./Errors.sol";
import { AppStorage, LibAppStorage } from "./Objects.sol";
import { LibConstants } from "./libs/LibConstants.sol";

abstract contract FacetBase is ERC2771Context {
    constructor() ERC2771Context(address(0)) {}

    modifier isAdmin() {
        if (LibDiamond.contractOwner() != _msgSender()) {
            revert CallerMustBeAdminError();
        }
        _;
    }

    modifier isServer() {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (s.addresses[LibConstants.SERVER_ADDRESS] != _msgSender()) {
            revert CallerMustBeServerError();
        }
        _;
    }
}
