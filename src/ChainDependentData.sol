// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

struct ChainDependent {
    address priceOracle;
    address currencyAddress;
}

function returnChainDependentData() view returns (ChainDependent memory data) {
    if (block.chainid == 5) {
        // data.priceOracle = 0xfAe941346Ac34908b8D7d000f86056A18049146E; // weth-usdc fee=500
        data.priceOracle = 0x6337B3caf9C5236c7f3D1694410776119eDaF9FA; // weth-usdc fee=3000
        data.currencyAddress = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6; // weth
    }

    if (block.chainid == 137) {
        data.priceOracle = 0xA374094527e1673A86dE625aa59517c5dE346d32; // wmatic-usdc fee=500
        data.currencyAddress = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // wmatic
    }
}
