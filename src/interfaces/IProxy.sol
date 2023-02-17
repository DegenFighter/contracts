// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { IDiamondCut } from "lib/diamond-2-hardhat/contracts/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "lib/diamond-2-hardhat/contracts/interfaces/IDiamondLoupe.sol";
import { IERC173 } from "lib/diamond-2-hardhat/contracts/interfaces/IERC173.sol";
import { IERC165 } from "lib/diamond-2-hardhat/contracts/interfaces/IERC165.sol";
import { ITokenImplFacet } from "./ITokenImplFacet.sol";
import { ISettingsFacet } from "./ISettingsFacet.sol";
import { IBettingFacet } from "./IBettingFacet.sol";
import { IInfoFacet } from "./IInfoFacet.sol";
import { IMemeMarketFacet } from "./IMemeMarketFacet.sol";

interface IProxy is
    IERC173,
    IERC165,
    IDiamondCut,
    IDiamondLoupe,
    ITokenImplFacet,
    ISettingsFacet,
    IBettingFacet,
    IInfoFacet,
    IMemeMarketFacet
{}
