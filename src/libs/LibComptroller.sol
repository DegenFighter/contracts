// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { AppStorage, LibAppStorage } from "../Objects.sol";
import { LibConstants } from "../libs/LibConstants.sol";

error FailedToSendEtherToServer();
error FailedToSendEtherToTreasury();

library LibComptroller {
    function _routeCoinPayment(uint256 amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (address(s.addresses[LibConstants.SERVER_ADDRESS]).balance < 0.5 ether) {
            // send coin to the server address
            (bool sent, ) = address(s.addresses[LibConstants.SERVER_ADDRESS]).call{ value: amount }(
                ""
            );
            if (!sent) {
                revert FailedToSendEtherToServer();
            }
        } else {
            // send coin to the treasury address
            (bool sent, ) = address(this).call{ value: amount }("");
            if (!sent) {
                revert FailedToSendEtherToTreasury();
            }
        }
    }
}
