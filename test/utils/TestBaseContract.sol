// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import "forge-std/Test.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { IProxy } from "../../src/interfaces/IProxy.sol";
import { Proxy } from "../../src/Proxy.sol";
import { LibConstants } from "../../src/libs/LibConstants.sol";
import { LibGeneratedFacetHelpers } from "../../script/generated/LibGeneratedFacetHelpers.sol";
import { MemeToken } from "../../src/MemeToken.sol";

contract TestBaseContract is Test {
    using stdStorage for StdStorage;

    address internal immutable account0 = address(this);
    bytes internal constant ERROR_MUST_BE_ADMIN = "LibDiamond: Must be contract owner";
    bytes internal constant ERROR_MUST_BE_SERVER = "Must be server";

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
        proxy.setAddress(LibConstants.SERVER_ADDRESS, account0);

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
