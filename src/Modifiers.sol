// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { LibDiamond } from "lib/diamond-2-hardhat/contracts/libraries/LibDiamond.sol";

abstract contract Modifiers {
    modifier isAdmin() {
        LibDiamond.enforceIsContractOwner();
        _;
    }
}
