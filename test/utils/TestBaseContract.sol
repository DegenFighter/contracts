// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { IProxy } from "../../src/interfaces/IProxy.sol";
import { Proxy } from "../../src/Proxy.sol";
import { LibConstants } from "../../src/libs/LibConstants.sol";
import { LibGeneratedFacetHelpers } from "../../script/generated/LibGeneratedFacetHelpers.sol";
import { MemeToken } from "../../src/MemeToken.sol";

struct Wallet {
    address addr;
    uint privateKey;
}

contract TestBaseContract is Test {
    using stdStorage for StdStorage;

    address internal immutable account0 = address(this);

    Wallet internal player1 = Wallet({ addr: vm.addr(1001), privateKey: 1001 });
    Wallet internal player2 = Wallet({ addr: vm.addr(1002), privateKey: 1002 });
    Wallet internal player3 = Wallet({ addr: vm.addr(1003), privateKey: 1003 });
    Wallet internal player4 = Wallet({ addr: vm.addr(1004), privateKey: 1004 });
    Wallet internal player5 = Wallet({ addr: vm.addr(1005), privateKey: 1005 });
    Wallet internal server = Wallet({ addr: vm.addr(12345), privateKey: 12345 });

    address internal proxyAddress;
    IProxy internal proxy;

    address internal memeTokenAddress;
    IERC20 internal memeToken;

    function setUp() public virtual {
        console2.log("account0", account0);
        console2.log("msg.sender", msg.sender);

        vm.label(account0, "Account 0 (Test Contract address)");

        // deploy proxy
        proxyAddress = address(new Proxy(address(this)));
        console.log("Address[proxy]: ", proxyAddress);
        vm.label(proxyAddress, "Proxy");
        LibGeneratedFacetHelpers.deployAndCutFacets(proxyAddress);

        proxy = IProxy(proxyAddress);

        // deploy token
        memeTokenAddress = address(new MemeToken(proxyAddress));
        console.log("Address[memeToken]: ", memeTokenAddress);
        vm.label(memeTokenAddress, "MemeToken");
        memeToken = IERC20(memeTokenAddress);
        proxy.setAddress(LibConstants.MEME_TOKEN_ADDRESS, memeTokenAddress);

        // set server address
        proxy.setAddress(LibConstants.SERVER_ADDRESS, server.addr);

        // set ownership
        proxy.transferOwnership(account0);
    }

    function enforceHasContractCode(address _contract, string memory _errorMessage) public view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }
}
