// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { AppStorage, LibAppStorage, MemeBuySizeDollars } from "../Objects.sol";
import { LibToken, LibTokenIds } from "../libs/LibToken.sol";
import { LibConstants } from "../libs/LibConstants.sol";
import { LibUniswapV3Twap } from "../libs/LibUniswapV3Twap.sol";
import { FixedPoint96 } from "lib/v3-core-08/contracts/libraries/FixedPoint96.sol";

library LibMeme {
    function getMemeCost(
        MemeBuySizeDollars size
    ) internal view returns (uint256 cost, uint256 buyAmount) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint160 sqrtPriceX96 = LibUniswapV3Twap.getSqrtTwapX96(s.priceOracle, s.twapInterval);

        uint256 priceX96 = LibUniswapV3Twap.getPriceX96FromSqrtPriceX96(sqrtPriceX96);

        if (size == MemeBuySizeDollars.Five) {
            buyAmount = 1_000 ether;
            cost = (priceX96 * 5e30) / FixedPoint96.Q96;
        } else if (size == MemeBuySizeDollars.Ten) {
            buyAmount = 2_500 ether;
            cost = (priceX96 * 10e30) / FixedPoint96.Q96;
        } else if (size == MemeBuySizeDollars.Twenty) {
            buyAmount = 6_000 ether;
            cost = (priceX96 * 20e30) / FixedPoint96.Q96;
        } else if (size == MemeBuySizeDollars.Fifty) {
            buyAmount = 20_000 ether;
            cost = (priceX96 * 50e30) / FixedPoint96.Q96;
        } else if (size == MemeBuySizeDollars.Hundred) {
            buyAmount = 50_000 ether;
            cost = (priceX96 * 100e30) / FixedPoint96.Q96;
        }
    }
}
