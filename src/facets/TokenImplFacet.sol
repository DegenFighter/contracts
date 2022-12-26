// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { AppStorage, LibAppStorage } from "../Base.sol";
import { ITokenImplFacet } from "../interfaces/ITokenImplFacet.sol";

contract TokenImplFacet is ITokenImplFacet {
    function tokenName(uint tokenId) external view returns (string memory) {
        return "Meme";
    }

    function tokenSymbol(uint tokenId) external view returns (string memory) {
        return "MEME";
    }

    function tokenDecimals(uint tokenId) external view returns (uint) {
        return 18;
    }

    function tokenTotalSupply(uint tokenId) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.memeSupply;
    }

    function tokenBalanceOf(uint tokenId, address account) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.memeBalance[account];
    }

    function tokenTransfer(uint tokenId, address to, uint256 amount) external returns (bool) {
        revert("not allowed");
    }

    function tokenAllowance(uint tokenId, address owner, address spender) external view returns (uint256) {
        return 0;
    }

    function tokenApprove(uint tokenId, address spender, uint256 amount) external returns (bool) {
        revert("not allowed");
    }

    function tokenTransferFrom(uint tokenId, address from, address to, uint256 amount) external returns (bool) {
        revert("not allowed");
    }
}
