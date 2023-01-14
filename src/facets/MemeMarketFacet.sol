// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { FacetBase } from "../FacetBase.sol";
import { NotAllowedError } from "../Errors.sol";
import { AppStorage, LibAppStorage, MemeBuySize } from "../Objects.sol";
import { ITokenImplFacet } from "../interfaces/ITokenImplFacet.sol";
import { LibConstants } from "../libs/LibConstants.sol";

import { LibToken } from "src/libs/LibToken.sol";
import { LibERC20 } from "src/erc20/LibERC20.sol";
import { LibUniswapV3Twap } from "src/libs/LibUniswapV3Twap.sol";
import { FixedPoint96 } from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

contract MemeMarketFacet is FacetBase {
    constructor() FacetBase() {}

    function buyMeme(MemeBuySize size) external returns (uint160 sqrtPriceX96, uint256 priceX96, uint256 amount, uint256 buyAmount) {
        // address uniswapV3Pool = 0xA374094527e1673A86dE625aa59517c5dE346d32; //wmatic-usdc fee=500
        address uniswapV3Pool = 0x9B08288C3Be4F62bbf8d1C20Ac9C5e6f9467d8B7; //wmatic-usdt fee=500
        uint32 twapInterval = 0; // todo adjust this value
        sqrtPriceX96 = LibUniswapV3Twap.getSqrtTwapX96(uniswapV3Pool, twapInterval);

        priceX96 = LibUniswapV3Twap.getPriceX96FromSqrtPriceX96(sqrtPriceX96);

        // get price of matic
        // amount of matic needed to purchase 1000 meme

        amount;

        buyAmount;

        if (size == MemeBuySize.Five) {
            buyAmount = 1_000 ether;
            amount = (priceX96 * 5e30) / FixedPoint96.Q96;
        } else if (size == MemeBuySize.Ten) {
            buyAmount = 2_500 ether;
            amount = (priceX96 * 10e30) / FixedPoint96.Q96;
        } else if (size == MemeBuySize.Twenty) {
            buyAmount = 6_000 ether;
            amount = (priceX96 * 20e30) / FixedPoint96.Q96;
        } else if (size == MemeBuySize.Fifty) {
            buyAmount = 20_000 ether;
            amount = (priceX96 * 50e30) / FixedPoint96.Q96;
        } else if (size == MemeBuySize.Hundred) {
            buyAmount = 50_000 ether;
            amount = (priceX96 * 100e30) / FixedPoint96.Q96;
        }

        // first, transfer wmatic to treasury
        LibERC20.transferFrom(LibConstants.WMATIC_POLYGON_ADDRESS, msg.sender, LibConstants.TREASURY_ADDRESS, amount);
        // LibERC20.transferFrom(LibConstants.WMATIC_POLYGON_ADDRESS, msg.sender, address(this), amount);

        LibToken.mint(LibConstants.TOKEN_MEME, msg.sender, buyAmount);
    }
}
