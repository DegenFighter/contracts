// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { SafeMath } from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

import { FacetBase } from "../FacetBase.sol";
import { NotAllowedError } from "../Errors.sol";
import { AppStorage, LibAppStorage, MemeBuySizeDollars } from "../Objects.sol";
import { ITokenImplFacet } from "../interfaces/ITokenImplFacet.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { LibConstants } from "../libs/LibConstants.sol";
import { LibToken, LibTokenIds } from "../libs/LibToken.sol";
import { ReentrancyGuard } from "../shared/ReentrancyGuard.sol";
import { LibComptroller } from "../libs/LibComptroller.sol";
import { LibMeme } from "../libs/LibMeme.sol";
import { LibBetting } from "../libs/LibBetting.sol";

error InsufficientCoin(uint256 required, uint256 available);
error FailedToReturnEthToUser(uint256 amount, uint256 gasLeft);

contract MemeFacet is FacetBase, ReentrancyGuard {
    using SafeMath for uint;

    function getAvailableMeme(
        address wallet,
        uint maxUnclaimedBouts
    ) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return
            LibBetting.getClaimableWinnings(wallet, maxUnclaimedBouts).add(
                s.tokenBalances[LibTokenIds.TOKEN_MEME][wallet]
            );
    }

    function getMemeCost(
        MemeBuySizeDollars size
    ) external view returns (uint256 cost, uint256 buyAmount) {
        (cost, buyAmount) = LibMeme.getMemeCost(size);
    }

    function buyMeme(
        MemeBuySizeDollars size
    )
        external
        payable
        nonReentrant
        returns (uint160 sqrtPriceX96, uint256 priceX96, uint256 cost, uint256 buyAmount)
    {
        (cost, buyAmount) = LibMeme.getMemeCost(size);

        if (msg.value < cost) {
            revert InsufficientCoin(cost, msg.value);
        }

        uint256 amountToSendBack = msg.value - cost;

        LibComptroller.routeCoinPayment(cost);

        // return the extra eth
        (bool sent, ) = address(_msgSender()).call{ value: amountToSendBack }("");
        // dev: how nice of us to return excess eth to the user :)
        if (!sent) {
            revert FailedToReturnEthToUser(amountToSendBack, gasleft());
        }

        LibToken.mint(LibTokenIds.TOKEN_MEME, _msgSender(), buyAmount);
    }
}
