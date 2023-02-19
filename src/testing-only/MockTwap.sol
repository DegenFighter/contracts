// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

contract MockTwap {
    address immutable admin;

    constructor() {
        admin = msg.sender;
    }

    modifier isAdmin() {
        if (msg.sender != admin) {
            revert("not admin");
        }
        _;
    }
    struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        uint16 observationIndex;
        // the current maximum number of observations that are being stored
        uint16 observationCardinality;
        // the next maximum number of observations to store, triggered in observations.write
        uint16 observationCardinalityNext;
        // the current protocol fee as a percentage of the swap fee taken on withdrawal
        // represented as an integer denominator (1/x)%
        uint8 feeProtocol;
        // whether the pool is locked
        bool unlocked;
    }
    Slot0 public slot0;

    function setSqrtPriceX96(uint160 sqrtPriceX96) external isAdmin {
        slot0.sqrtPriceX96 = sqrtPriceX96;
    }

    function observe(
        uint32[] calldata secondsAgos
    )
        external
        view
        returns (
            int56[] memory tickCumulatives,
            uint160[] memory secondsPerLiquidityCumulativeX128s
        )
    {
        tickCumulatives = new int56[](2);

        tickCumulatives[0] = int56(1);
        tickCumulatives[1] = int56(2);
    }
}