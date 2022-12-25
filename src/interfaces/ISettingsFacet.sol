// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

interface ISettingsFacet {
    function memeToken() external view returns (address);

    function setMemeToken(address addr) external;
}
