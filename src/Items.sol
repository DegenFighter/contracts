// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { IERC1155 } from "lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import { ITokenImplFacet } from "./interfaces/ITokenImplFacet.sol";
import { LibConstants } from "./libs/LibConstants.sol";
import { NotAllowedError } from "src/Errors.sol";

contract Items is IERC1155 {
    ITokenImplFacet public impl;

    constructor(address _impl) {
        impl = ITokenImplFacet(_impl);
    }

    function balanceOf(address wallet, uint256 id) public view override returns (uint256) {
        require(wallet != address(0), "ERC1155: address zero is not a valid owner");
        return impl.tokenBalanceOf(id, wallet);
    }

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) public view override returns (uint256[] memory) {
        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = impl.tokenBalanceOf(ids[i], accounts[i]);
        }

        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) external override {
        revert NotAllowedError();
    }

    function isApprovedForAll(address account, address operator) external view override returns (bool) {
        revert NotAllowedError();
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external {
        revert NotAllowedError();
    }

    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external {
        revert NotAllowedError();
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {}
}
