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
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);

    constructor() FacetBase() {}

    function createItem(uint256 itemId, uint256 cost) external isAdmin {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (cost < 1e18) {
            revert("create item that costs more than 1 meme");
        }
        s.itemForSale[itemId] = true;

        s.costOfItem[itemId] = cost;

        // todo emit event
    }

    function buyItem(uint256 itemId, uint256 amount) external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (!s.itemForSale[itemId]) {
            revert("item not for sale");
        }

        uint256 userBalance = s.tokenBalances[LibTokenIds.TOKEN_MEME][msg.sender];
        uint256 totalCost = s.costOfItem[itemId] * amount;
        require(userBalance >= totalCost, "not enough meme");

        // burn
        LibToken.burn(LibTokenIds.TOKEN_MEME, msg.sender, totalCost);

        s.tokenBalances[itemId][msg.sender] += amount;
        emit TransferSingle(msg.sender, address(0), msg.sender, itemId, amount);
    }

    function buyItems(uint256[] memory itemIds, uint256[] memory amounts) external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        for (uint256 i = 0; i < itemIds.length; i++) {
            if (!s.itemForSale[itemIds[i]]) {
                revert("item not for sale");
            }
        }

        uint256 userBalance = s.tokenBalances[LibTokenIds.TOKEN_MEME][msg.sender];
        uint256 totalCost;

        for (uint256 i = 0; i < amounts.length; i++) {
            totalCost = totalCost + (s.costOfItem[itemIds[i]] * amounts[i]);
        }

        require(userBalance >= totalCost, "not enough meme");

        LibToken.burn(LibTokenIds.TOKEN_MEME, msg.sender, totalCost);

        for (uint256 i = 0; i < itemIds.length; i++) {
            s.tokenBalances[itemIds[i]][msg.sender] += amounts[i];
        }

        emit TransferBatch(msg.sender, address(0), msg.sender, itemIds, amounts);
    }
}
