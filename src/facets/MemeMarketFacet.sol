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

contract MemeMarketFacet is FacetBase {
    constructor() FacetBase() {}

    function buyMeme(MemeBuySizeDollars size) external returns (uint160 sqrtPriceX96, uint256 priceX96, uint256 amount, uint256 buyAmount) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // get price of matic
        sqrtPriceX96 = LibUniswapV3Twap.getSqrtTwapX96(s.priceOracle, s.twapInterval);

        priceX96 = LibUniswapV3Twap.getPriceX96FromSqrtPriceX96(sqrtPriceX96);

        if (size == MemeBuySizeDollars.Five) {
            buyAmount = 1_000 ether;
            amount = (priceX96 * 5e30) / FixedPoint96.Q96;
        } else if (size == MemeBuySizeDollars.Ten) {
            buyAmount = 2_500 ether;
            amount = (priceX96 * 10e30) / FixedPoint96.Q96;
        } else if (size == MemeBuySizeDollars.Twenty) {
            buyAmount = 6_000 ether;
            amount = (priceX96 * 20e30) / FixedPoint96.Q96;
        } else if (size == MemeBuySizeDollars.Fifty) {
            buyAmount = 20_000 ether;
            amount = (priceX96 * 50e30) / FixedPoint96.Q96;
        } else if (size == MemeBuySizeDollars.Hundred) {
            buyAmount = 50_000 ether;
            amount = (priceX96 * 100e30) / FixedPoint96.Q96;
        }

        // first, transfer wmatic to treasury
        IERC20 wmatic = IERC20(s.currencyAddress);
        wmatic.transferFrom(msg.sender, s.addresses[LibConstants.TREASURY_ADDRESS], amount);

        LibToken.mint(LibTokenIds.TOKEN_MEME, msg.sender, buyAmount);
    }
}
