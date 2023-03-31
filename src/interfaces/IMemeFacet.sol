// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { MemeBuySizeDollars } from "../Objects.sol";

interface IMemeFacet {
    /**
     * @dev Returns the MEME balance of the wallet + ALL unclaimed winnings.
     */
    function getAvailableMeme(
        address wallet,
        uint maxUnclaimedBouts
    ) external view returns (uint256);

    function getMemeCost(
        MemeBuySizeDollars size
    ) external view returns (uint256 cost, uint256 buyAmount);

    function buyMeme(MemeBuySizeDollars size) external payable;
}
