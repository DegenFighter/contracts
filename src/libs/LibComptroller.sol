// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { AppStorage, LibAppStorage } from "../Objects.sol";
import { LibConstants } from "../libs/LibConstants.sol";

error FailedToSendEtherToServer(address to);
error FailedToSendEtherToTreasury();

library LibComptroller {
    function _routeCoinPayment(uint256 amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        address serverAddress = s.addresses[LibConstants.SERVER_ADDRESS];
        if (address(serverAddress).balance < 0.5 ether) {
            // send coin to the server address
            (bool sent, ) = address(serverAddress).call{ value: amount }("");
            if (!sent) {
                revert FailedToSendEtherToServer(serverAddress);
            }
        } else {
            // send coin to the treasury address, which is the proxy / diamond contract
            (bool sent, ) = address(this).call{ value: amount }("");
            if (!sent) {
                revert FailedToSendEtherToTreasury();
            }
        }
    }
}
