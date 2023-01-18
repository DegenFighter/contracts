// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { FacetBase } from "../FacetBase.sol";
import { NotAllowedError } from "../Errors.sol";
import { AppStorage, LibAppStorage, MemeBuySizeDollars } from "../Objects.sol";
import { ITokenImplFacet } from "../interfaces/ITokenImplFacet.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { LibConstants, LibTokenIds } from "../libs/LibConstants.sol";

import { LibToken } from "src/libs/LibToken.sol";
import { LibUniswapV3Twap } from "src/libs/LibUniswapV3Twap.sol";
import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

contract ItemsMarketFacet is FacetBase {
    constructor() FacetBase() {}

    function createItem(uint256 itemId) external isAdmin {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.itemForSale[itemId] = true;
        // todo emit event
    }

    function buyItem(uint256 itemId, uint256 amount) external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (!s.itemForSale[itemId]) {
            revert("item not for sale");
        }

        // cost of
        // broadcast - 100 meme
        if (itemId == LibTokenIds.BROADCAST_MSG) {
            uint256 userBalance = s.tokenBalances[LibTokenIds.BROADCAST_MSG][msg.sender];
            require(userBalance >= 100e18, "not enough meme");

            unchecked {
                s.tokenBalances[LibTokenIds.BROADCAST_MSG][msg.sender] - 100e18;
                // todo also update total supply
                // todo emit transfer to zero address
            }
            LibToken.mint(LibTokenIds.BROADCAST_MSG, msg.sender, amount);
        }
    }
}
