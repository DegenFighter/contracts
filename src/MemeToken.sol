// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IInternalTokenImpl } from "./interfaces/IInternalTokenImpl.sol";

contract MemeToken is IERC20 {
    IInternalTokenImpl public impl;

    constructor(address _impl) {
        impl = IInternalTokenImpl(_impl);
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
