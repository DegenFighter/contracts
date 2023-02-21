// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { FacetBase } from "../FacetBase.sol";
import { NotAllowedError } from "../Errors.sol";
import { AppStorage, LibAppStorage, MemeBuySizeDollars } from "../Objects.sol";
import { ITokenImplFacet } from "../interfaces/ITokenImplFacet.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { LibConstants } from "../libs/LibConstants.sol";
import { LibToken, LibTokenIds } from "../libs/LibToken.sol";
import { ReentrancyGuard } from "../shared/ReentrancyGuard.sol";
import { LibComptroller } from "../libs/LibComptroller.sol";
import { LibMemeMarket } from "../libs/LibMemeMarket.sol";

error InsufficientCoin(uint256 required, uint256 available);
error FailedToReturnEthToUser(uint256 amount, uint256 gasLeft);

contract MemeMarketFacet is FacetBase, ReentrancyGuard {
    function claimFreeMeme() external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        address wallet = _msgSender();

        uint256 bal = s.tokenBalances[LibTokenIds.TOKEN_MEME][wallet];

        if (bal < LibConstants.MIN_BET_AMOUNT) {
            LibToken.mint(LibTokenIds.TOKEN_MEME, wallet, LibConstants.MIN_BET_AMOUNT - bal);
        }
    }

    function getMemeCost(
        MemeBuySizeDollars size
    ) external view returns (uint256 cost, uint256 buyAmount) {
        (cost, buyAmount) = LibMemeMarket._getMemeCost(size);
    }

    function buyMeme(
        MemeBuySizeDollars size
    )
        external
        payable
        nonReentrant
        returns (uint160 sqrtPriceX96, uint256 priceX96, uint256 cost, uint256 buyAmount)
    {
        (cost, buyAmount) = LibMemeMarket._getMemeCost(size);

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
