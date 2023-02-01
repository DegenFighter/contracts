// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { IDiamondCut } from "lib/diamond-2-hardhat/contracts/interfaces/IDiamondCut.sol";

import { AppStorage, LibAppStorage, BoutState } from "../../src/Objects.sol";
import { LibConstants } from "../../src/libs/LibConstants.sol";
import { LibToken, LibTokenIds } from "../../src/libs/LibToken.sol";
import { InitDiamond } from "src/InitDiamond.sol";

contract TestFacet1 {
    function _testMintMeme(address wallet, uint amount) external {
        LibToken.mint(LibTokenIds.TOKEN_MEME, wallet, amount);
    }

    function _testSetBoutState(uint boutId, BoutState state) external {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.bouts[boutId].state = state;
    }

    function _testGetUserWinningsToClaimListLength(address wallet) external returns (uint) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.userBoutsWinningsToClaimList[wallet].len;
    }

    function _testSetBoutExpiryTime(uint boutId, uint expiryTime) external {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.bouts[boutId].expiryTime = expiryTime;
    }
}

abstract contract ITestFacet is TestFacet1 {}

library LibTestFacetsHelper {
    function deployAndCutTestFacets(address proxy) internal {
        address testFacet1 = address(new TestFacet1());

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);

        bytes4[] memory f1 = new bytes4[](4);
        f1[0] = TestFacet1._testMintMeme.selector;
        f1[1] = TestFacet1._testSetBoutState.selector;
        f1[2] = TestFacet1._testGetUserWinningsToClaimListLength.selector;
        f1[3] = TestFacet1._testSetBoutExpiryTime.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: testFacet1,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: f1
        });

        InitDiamond initDiamond = new InitDiamond();
        IDiamondCut(proxy).diamondCut(
            cut,
            address(initDiamond),
            abi.encodeCall(initDiamond.initialize, ())
        );
    }
}
