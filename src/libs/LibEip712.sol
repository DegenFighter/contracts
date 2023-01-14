// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { ECDSA } from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { AppStorage, LibAppStorage } from "../Objects.sol";

// Based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/EIP712.sol
library LibEip712 {
    function init(string memory name, string memory version) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        bytes32 hashedName = keccak256(bytes(name));
        bytes32 hashedVersion = keccak256(bytes(version));
        bytes32 typeHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        s.eip712.HASHED_NAME = hashedName;
        s.eip712.HASHED_VERSION = hashedVersion;
        s.eip712.CACHED_CHAIN_ID = block.chainid;
        s.eip712.CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(typeHash, hashedName, hashedVersion);
        s.eip712.CACHED_THIS = address(this);
        s.eip712.TYPE_HASH = typeHash;
    }

    function domainSeparatorV4() internal view returns (bytes32) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (address(this) == s.eip712.CACHED_THIS && block.chainid == s.eip712.CACHED_CHAIN_ID) {
            return s.eip712.CACHED_DOMAIN_SEPARATOR;
        } else {
            return _buildDomainSeparator(s.eip712.TYPE_HASH, s.eip712.HASHED_NAME, s.eip712.HASHED_VERSION);
        }
    }

    function hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        return ECDSA.toTypedDataHash(domainSeparatorV4(), structHash);
    }

    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        return ECDSA.recover(hash, v, r, s);
    }

    function _buildDomainSeparator(bytes32 typeHash, bytes32 nameHash, bytes32 versionHash) private view returns (bytes32) {
        return keccak256(abi.encode(typeHash, nameHash, versionHash, block.chainid, address(this)));
    }
}
