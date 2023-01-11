// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { AppStorage, LibAppStorage } from "../Objects.sol";
import { TokenBalanceInsufficient } from "../Errors.sol";
import { SafeMath } from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

library LibToken {
    using SafeMath for uint;

    function transfer(uint tokenId, address from, address to, uint amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (amount > s.tokenBalances[tokenId][from]) {
            revert TokenBalanceInsufficient();
        }

        if (from != to) {
            s.tokenBalances[tokenId][from] = s.tokenBalances[tokenId][from].sub(amount);
            s.tokenBalances[tokenId][to] = s.tokenBalances[tokenId][to].add(amount);
        }
    }
}
