// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { IDiamondCut } from "lib/diamond-2-hardhat/contracts/interfaces/IDiamondCut.sol";

import { AppStorage, LibAppStorage } from "../../src/Objects.sol";
import { LibConstants } from "../../src/libs/LibConstants.sol";
import { LibToken } from "../../src/libs/LibToken.sol";

contract TestFacet1 {
    function mintMeme(address wallet, uint amount) external {
        LibToken.mint(LibConstants.TOKEN_MEME, wallet, amount);
    }
}

abstract contract ITestFacet is TestFacet1 {}

library LibTestFacetsHelper {
    function deployAndCutTestFacets(address proxy) internal {
        address testFacet1 = address(new TestFacet1());

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);

        bytes4[] memory f1 = new bytes4[](1);
        f1[0] = TestFacet1.mintMeme.selector;
        cut[0] = IDiamondCut.FacetCut({ facetAddress: testFacet1, action: IDiamondCut.FacetCutAction.Add, functionSelectors: f1 });

        IDiamondCut(proxy).diamondCut(cut, address(0), "");
    }
}
