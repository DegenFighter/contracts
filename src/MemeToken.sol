// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ITokenImplFacet } from "./interfaces/ITokenImplFacet.sol";
import { LibTokenIds } from "./libs/LibToken.sol";

contract MemeToken is IERC20 {
    ITokenImplFacet public impl;

    constructor(address _impl) {
        impl = ITokenImplFacet(_impl);
    }

    function name() external view returns (string memory) {
        return impl.tokenName(LibTokenIds.TOKEN_MEME);
    }

    function symbol() external view returns (string memory) {
        return impl.tokenSymbol(LibTokenIds.TOKEN_MEME);
    }

    function decimals() external view returns (uint256) {
        return impl.tokenDecimals(LibTokenIds.TOKEN_MEME);
    }

    function totalSupply() external view override returns (uint256) {
        return impl.tokenTotalSupply(LibTokenIds.TOKEN_MEME);
    }

    function balanceOf(address wallet) external view override returns (uint256) {
        return impl.tokenBalanceOf(LibTokenIds.TOKEN_MEME, wallet);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return impl.tokenTransfer(LibTokenIds.TOKEN_MEME, recipient, amount);
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return impl.tokenAllowance(LibTokenIds.TOKEN_MEME, owner, spender);
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        return impl.tokenApprove(LibTokenIds.TOKEN_MEME, spender, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        return impl.tokenTransferFrom(LibTokenIds.TOKEN_MEME, sender, recipient, amount);
    }
}
