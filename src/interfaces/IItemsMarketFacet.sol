// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

interface IItemsMarketFacet {
    function createItem(uint256 itemId, uint256 cost) external;

    function buyItem(uint256 itemId, uint256 amount) external;

    function buyItems(uint256[] memory itemIds, uint256[] memory amounts) external;
}
