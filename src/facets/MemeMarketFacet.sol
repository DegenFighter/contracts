// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { FixedPoint96 } from "lib/v3-core-08/contracts/libraries/FixedPoint96.sol";

import { FacetBase } from "../FacetBase.sol";
import { NotAllowedError } from "../Errors.sol";
import { AppStorage, LibAppStorage, MemeBuySizeDollars } from "../Objects.sol";
import { ITokenImplFacet } from "../interfaces/ITokenImplFacet.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { LibConstants } from "../libs/LibConstants.sol";
import { LibToken, LibTokenIds } from "../libs/LibToken.sol";
import { LibUniswapV3Twap } from "../libs/LibUniswapV3Twap.sol";
import { ReentrancyGuard } from "../shared/ReentrancyGuard.sol";
import { FixedPointMathLib } from "lib/solmate/src/utils/FixedPointMathLib.sol";
import { LibComptroller } from "../libs/LibComptroller.sol";

error InsufficientCoin(uint256 required, uint256 available);
error FailedToReturnEthToUser(uint256 amount, uint256 gasLeft);

contract MemeMarketFacet is FacetBase, ReentrancyGuard {
    using FixedPointMathLib for uint256;

    function claimFreeMeme() external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        address wallet = _msgSender();

        uint256 bal = s.tokenBalances[LibTokenIds.TOKEN_MEME][wallet];

        if (bal < LibConstants.MIN_BET_AMOUNT) {
            LibToken.mint(LibTokenIds.TOKEN_MEME, wallet, LibConstants.MIN_BET_AMOUNT - bal);
        }
    }

    function buyMeme(
        MemeBuySizeDollars size
    )
        external
        payable
        nonReentrant
        returns (uint160 sqrtPriceX96, uint256 priceX96, uint256 cost, uint256 buyAmount)
    {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // get price
        sqrtPriceX96 = LibUniswapV3Twap.getSqrtTwapX96(s.priceOracle, s.twapInterval);

        priceX96 = LibUniswapV3Twap.getPriceX96FromSqrtPriceX96(sqrtPriceX96);

        if (size == MemeBuySizeDollars.Five) {
            buyAmount = 1_000 ether;
            cost = (priceX96 * 5e30) / FixedPoint96.Q96;
            // cost = uint256(5).divWadUp(1500);
        } else if (size == MemeBuySizeDollars.Ten) {
            buyAmount = 2_500 ether;
            cost = (priceX96 * 10e30) / FixedPoint96.Q96;
            // cost = uint256(10).divWadUp(1500);
        } else if (size == MemeBuySizeDollars.Twenty) {
            buyAmount = 6_000 ether;
            cost = (priceX96 * 20e30) / FixedPoint96.Q96;
            // cost = uint256(20).divWadUp(1500);
        } else if (size == MemeBuySizeDollars.Fifty) {
            buyAmount = 20_000 ether;
            cost = (priceX96 * 50e30) / FixedPoint96.Q96;
            // cost = uint256(50).divWadUp(1500);
        } else if (size == MemeBuySizeDollars.Hundred) {
            buyAmount = 50_000 ether;
            cost = (priceX96 * 100e30) / FixedPoint96.Q96;
            // cost = uint256(100).divWadUp(1500);
        }

        if (msg.value < cost) {
            revert InsufficientCoin(cost, msg.value);
        }

        uint256 amountToSendBack = msg.value - cost;

        LibComptroller._routeCoinPayment(cost);

        // return the extra eth
        (bool sent, ) = address(_msgSender()).call{ value: amountToSendBack }("");
        // dev: how nice of us to return excess eth to the user :)
        if (!sent) {
            revert FailedToReturnEthToUser(amountToSendBack, gasleft());
        }

        LibToken.mint(LibTokenIds.TOKEN_MEME, _msgSender(), buyAmount);
    }
}
