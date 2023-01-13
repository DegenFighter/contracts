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

address constant WMATIC_POLYGON_ADDRESS = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
address constant TREASURY_ADDRESS = address(0xDFDFDFDF);

contract MemeMarketFacet is FacetBase {
    constructor() FacetBase() {}

    function buyMeme(MemeBuySize size) external {
        address uniswapV3Pool = 0xA374094527e1673A86dE625aa59517c5dE346d32; //wmatic-usdc fee=500
        uint32 twapInterval = 4800; // todo adjust this value
        uint160 sqrtPriceX96 = LibUniswapV3Twap.getSqrtTwapX96(uniswapV3Pool, twapInterval);

        uint256 priceX96 = LibUniswapV3Twap.getPriceX96FromSqrtPriceX96(sqrtPriceX96);
        // get price of matic
        // amount of matic needed to purchase 1000 meme

        uint256 amount;

        uint256 buyAmount;

        if (size == MemeBuySize.Five) {
            buyAmount = 1_000 ether;
            amount = 5 ether / priceX96; //todo fix
        } else if (size == MemeBuySize.Ten) {
            buyAmount = 2_500 ether;
        } else if (size == MemeBuySize.Twenty) {
            buyAmount = 6_000 ether;
        } else if (size == MemeBuySize.Fifty) {
            buyAmount = 20_000 ether;
        } else if (size == MemeBuySize.Hundred) {
            buyAmount = 50_000 ether;
        }

        // first, transfer wmatic to treasury
        LibERC20.transfer(WMATIC_POLYGON_ADDRESS, TREASURY_ADDRESS, amount);

        LibToken.mint(LibConstants.TOKEN_MEME, msg.sender, buyAmount);
    }
}
