// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ITokenImplFacet } from "./interfaces/ITokenImplFacet.sol";

contract MemeToken is IERC20 {
    ITokenImplFacet public impl;

    constructor(address _impl) {
        impl = ITokenImplFacet(_impl);
    }

    function name() external view returns (string memory) {
        return impl.tokenName(0);
    }

    function symbol() external view returns (string memory) {
        return impl.tokenSymbol(0);
    }

    function decimals() external view returns (uint256) {
        return impl.tokenDecimals(0);
    }

    function totalSupply() external view override returns (uint256) {
        return impl.tokenTotalSupply(0);
    }

    function balanceOf(address wallet) external view override returns (uint256) {
        return impl.tokenBalanceOf(0, wallet);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return impl.tokenTransfer(0, recipient, amount);
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return impl.tokenAllowance(0, owner, spender);
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        return impl.tokenApprove(0, spender, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        return impl.tokenTransferFrom(0, sender, recipient, amount);
    }
}
