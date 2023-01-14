// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ITokenImplFacet } from "./interfaces/ITokenImplFacet.sol";
import { LibConstants } from "./libs/LibConstants.sol";

contract MemeToken is IERC20 {
    ITokenImplFacet public impl;

    constructor(address _impl) {
        impl = ITokenImplFacet(_impl);
    }

    function name() external view returns (string memory) {
        return impl.tokenName(LibConstants.TOKEN_MEME);
    }

    function symbol() external view returns (string memory) {
        return impl.tokenSymbol(LibConstants.TOKEN_MEME);
    }

    function decimals() external view returns (uint256) {
        return impl.tokenDecimals(LibConstants.TOKEN_MEME);
    }

    function totalSupply() external view override returns (uint256) {
        return impl.tokenTotalSupply(LibConstants.TOKEN_MEME);
    }

    function balanceOf(address wallet) external view override returns (uint256) {
        return impl.tokenBalanceOf(LibConstants.TOKEN_MEME, wallet);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return impl.tokenTransfer(LibConstants.TOKEN_MEME, recipient, amount);
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return impl.tokenAllowance(LibConstants.TOKEN_MEME, owner, spender);
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        return impl.tokenApprove(LibConstants.TOKEN_MEME, spender, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        return impl.tokenTransferFrom(LibConstants.TOKEN_MEME, sender, recipient, amount);
    }
}
