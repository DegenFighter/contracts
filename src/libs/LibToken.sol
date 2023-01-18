// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { AppStorage, LibAppStorage } from "../Objects.sol";
import { TokenBalanceInsufficient } from "../Errors.sol";
import { SafeMath } from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

library LibToken {
    using SafeMath for uint;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function transfer(uint tokenId, address from, address to, uint amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (amount > s.tokenBalances[tokenId][from]) {
            revert TokenBalanceInsufficient(s.tokenBalances[tokenId][from], amount);
        }

        if (from != to) {
            s.tokenBalances[tokenId][from] = s.tokenBalances[tokenId][from].sub(amount);
            s.tokenBalances[tokenId][to] = s.tokenBalances[tokenId][to].add(amount);
        }
    }

    function mint(uint tokenId, address wallet, uint amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.tokenBalances[tokenId][wallet] = s.tokenBalances[tokenId][wallet].add(amount);
        s.tokenSupply[tokenId] = s.tokenSupply[tokenId].add(amount);

        emit Transfer(address(0), wallet, amount);
    }

    function burn(uint tokenId, address wallet, uint amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        unchecked {
            s.tokenBalances[tokenId][wallet] - amount;
            s.tokenSupply[tokenId] - amount;
        }
        emit Transfer(wallet, address(0), amount);
    }
}
