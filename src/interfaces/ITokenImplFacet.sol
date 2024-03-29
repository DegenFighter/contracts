// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

interface ITokenImplFacet {
    /**
     * @dev Returns the name.
     */
    function tokenName(uint tokenId) external view returns (string memory);

    /**
     * @dev Returns the symbol.
     */
    function tokenSymbol(uint tokenId) external view returns (string memory);

    /**
     * @dev Returns the decimals.
     */
    function tokenDecimals(uint tokenId) external view returns (uint);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function tokenTotalSupply(uint tokenId) external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `wallet`.
     */
    function tokenBalanceOf(uint tokenId, address wallet) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function tokenTransfer(uint tokenId, address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function tokenAllowance(uint tokenId, address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function tokenApprove(uint tokenId, address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function tokenTransferFrom(uint tokenId, address from, address to, uint256 amount) external returns (bool);
}
