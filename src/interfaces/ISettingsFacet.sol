// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

interface ISettingsFacet {
    /**
     * @dev Get an address.
     * @param key The key to get.
     * @return The address.
     */
    function getAddress(bytes32 key) external view returns (address);

    /**
     * @dev Set an address.
     * @param key The key to set.
     * @param value The value to set.
     */
    function setAddress(bytes32 key, address value) external;

    function setTwapParams(address priceOracle, uint32 twapInterval, address currencyAddress) external;
}
