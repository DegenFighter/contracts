// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

interface IItemsMarketFacet {
    function createItem(uint256 itemId) external;

    function buyItem(uint256 itemId, uint256 amount) external;
}
