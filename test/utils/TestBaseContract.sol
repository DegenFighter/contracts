// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import { ECDSA } from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { IProxy } from "../../src/interfaces/IProxy.sol";
import { Proxy } from "../../src/Proxy.sol";
import { LibConstants } from "../../src/libs/LibConstants.sol";
import { LibGeneratedFacetHelpers } from "../../script/generated/LibGeneratedFacetHelpers.sol";
import { MemeToken } from "../../src/MemeToken.sol";
import { ITestFacet, LibTestFacetsHelper } from "./TestFacets.sol";
import { BoutState, BoutFighter } from "../../src/Objects.sol";

struct Wallet {
    address addr;
    uint privateKey;
}

abstract contract ITestProxy is ITestFacet, IProxy {}

contract TestBaseContract is Test {
    using stdStorage for StdStorage;

    // ------------------------------------------------------ //
    // Default protocol level test constant variables
    // ------------------------------------------------------ //
    address internal immutable account0 = address(this);

    // ------------------------------------------------------ //
    // Default protocol level test wallets and addresses
    // ------------------------------------------------------ //
    Wallet[] internal players;

    Wallet internal server = Wallet({ addr: vm.addr(12345), privateKey: 12345 });

    address internal proxyAddress;
    ITestProxy internal proxy;

    address internal memeTokenAddress;
    IERC20 internal memeToken;

    // ------------------------------------------------------ //
    // Other variables
    // ------------------------------------------------------ //
    uint internal randomNonce;

    function setUp() public virtual {
        console2.log("account0", account0);
        console2.log("msg.sender", msg.sender);

        vm.label(account0, "Account 0 (Test Contract address)");

        // deploy proxy
        proxyAddress = address(new Proxy(address(this)));
        console.log("Address[proxy]: ", proxyAddress);
        vm.label(proxyAddress, "Proxy");
        LibGeneratedFacetHelpers.deployAndCutFacets(proxyAddress);
        LibTestFacetsHelper.deployAndCutTestFacets(proxyAddress);

        proxy = ITestProxy(proxyAddress);

        // deploy token
        memeTokenAddress = address(new MemeToken(proxyAddress));
        console.log("Address[memeToken]: ", memeTokenAddress);
        vm.label(memeTokenAddress, "MemeToken");
        memeToken = IERC20(memeTokenAddress);
        proxy.setAddress(LibConstants.MEME_TOKEN_ADDRESS, memeTokenAddress);

        // set server address
        proxy.setAddress(LibConstants.SERVER_ADDRESS, server.addr);
        vm.label(server.addr, "Server");

        // set ownership
        proxy.transferOwnership(account0);

        // setup players
        for (uint i = 0; i < 5; i++) {
            players.push(Wallet({ addr: vm.addr(1001 + i), privateKey: 1001 + i }));
            vm.label(players[i].addr, string(abi.encodePacked("Player ", i)));
        }
    }

    // ------------------------------------------------------ //
    //
    // Custom assertions
    //
    // ------------------------------------------------------ //

    function assertEq(uint8[] memory a, uint8[] memory b, string memory err) internal {
        assertEq(a.length, b.length, err);
        for (uint i = 0; i < a.length; i++) {
            assertEq(a[i], b[i], err);
        }
    }

    function assertEq(BoutState a, BoutState b, string memory err) internal {
        assertEq(uint(a), uint(b), err);
    }

    function assertEq(BoutFighter a, BoutFighter b, string memory err) internal {
        assertEq(uint(a), uint(b), err);
    }

    function sign(
        uint256 privateKey,
        bytes32 digest
    ) internal returns (uint8 v, bytes32 r, bytes32 s) {
        return vm.sign(privateKey, ECDSA.toEthSignedMessageHash(digest));
    }

    function randUint() internal returns (uint256) {
        randomNonce++;
        // returns number between 0 and 99
        return
            uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, randomNonce))) %
            100;
    }
}
