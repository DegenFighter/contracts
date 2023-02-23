// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { AppStorage, LibAppStorage } from "../Objects.sol";
import { LibConstants } from "../libs/LibConstants.sol";

error FailedToSendEtherToServer(address to);

library LibComptroller {
    function routeCoinPayment(uint256 amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        address serverAddress = s.addresses[LibConstants.SERVER_ADDRESS];
        if (address(serverAddress).balance < LibConstants.SERVER_COIN_TRESHOLD) {
            // send coin to the server address
            (bool sent, ) = address(serverAddress).call{ value: amount }("");
            if (!sent) {
                revert FailedToSendEtherToServer(serverAddress);
            }
        }
    }
}
