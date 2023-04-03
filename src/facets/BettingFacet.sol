// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { SafeMath } from "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

import "../Errors.sol";
import { AppStorage, LibAppStorage, Bout, BoutState, BoutFighter } from "../Objects.sol";
import { IBettingFacet } from "../interfaces/IBettingFacet.sol";
import { FacetBase } from "../FacetBase.sol";
import { LibConstants } from "../libs/LibConstants.sol";
import { LibEip712 } from "../libs/LibEip712.sol";
import { LibToken, LibTokenIds } from "../libs/LibToken.sol";
import { LibBetting } from "../libs/LibBetting.sol";

contract BettingFacet is FacetBase, IBettingFacet {
    using SafeMath for uint;

    function bet(
        uint boutId,
        uint8 br,
        uint amount,
        uint deadline,
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS
    ) external {
        AppStorage storage s = LibAppStorage.diamondStorage();

        address bettor = _msgSender();

        // recover signer
        address server = s.addresses[LibConstants.SERVER_ADDRESS];
        bytes32 digest = LibBetting.calculateBetSignatureDigest(
            server,
            bettor,
            boutId,
            br,
            amount,
            deadline
        );
        address signer = LibEip712.recover(
            LibEip712.toEthSignedMessageHash(digest),
            sigV,
            sigR,
            sigS
        );

        // check signature
        if (signer != server) {
            revert SignerMustBeServerError();
        }

        if (block.timestamp >= deadline) {
            revert SignatureExpiredError();
        }

        // do it
        LibBetting.bet(boutId, bettor, br, amount);

        emit BetPlaced(boutId, bettor);
    }

    function endBout(
        uint boutId,
        uint fighterAId,
        uint fighterBId,
        uint fighterAPot,
        uint fighterBPot,
        BoutFighter winner,
        uint8[] calldata revealValues
    ) external isServer {
        LibBetting.endBout(
            boutId,
            fighterAId,
            fighterBId,
            fighterAPot,
            fighterBPot,
            winner,
            revealValues
        );

        emit BoutEnded(boutId);
    }

    function getBoutClaimableAmounts(
        uint boutId,
        address wallet
    ) external view returns (uint totalToClaim, uint selfBetAmount, uint loserPotAmountToClaim) {
        return LibBetting.getBoutClaimableAmounts(boutId, wallet);
    }

    function getLatestClaimableWinnings(address wallet) external view returns (uint) {
        return LibBetting.getLatestClaimableWinnings(wallet);
    }

    function getClaimableWinnings(
        address wallet,
        uint maxBoutsToClaim
    ) external view returns (uint) {
        return LibBetting.getClaimableWinnings(wallet, maxBoutsToClaim);
    }

    function claimLatestWinnings(address wallet) external {
        LibBetting.claimLatestWinnings(wallet);
    }

    function claimWinnings(address wallet, uint maxBoutsToClaim) external {
        LibBetting.claimWinnings(wallet, maxBoutsToClaim);
    }

    function calculateBetSignatureDigest(
        address server,
        address bettor,
        uint256 boutId,
        uint8 br,
        uint256 amount,
        uint256 deadline
    ) external view returns (bytes32) {
        return LibBetting.calculateBetSignatureDigest(server, bettor, boutId, br, amount, deadline);
    }
}
