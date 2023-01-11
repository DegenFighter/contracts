// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { BoutState, BoutParticipant } from "./Objects.sol";

error NotAllowedError();

error CallerMustBeAdminError();
error CallerMustBeServerError();
error SignerMustBeServerError();
error SignatureExpiredError();

/*
TODO: I haven't yet figured out how to encode the error and parameters 
in test code in order to check the revert bytes, so for now we'll omit 
parameters from error.
 */
error BoutInWrongStateError(); //uint boutNum, BoutState state);
error MinimumBetAmountError(); //uint boutNum, address supporter, uint amount);
error InvalidBetTargetError(); //uint boutNum, address supporter, uint8 br);
error BoutAlreadyFullyRevealedError(); //uint boutNum);
error BoutAlreadyEndedError(); //uint boutNum);
error InvalidWinnerError(); //uint boutNum, BoutParticipant winner);

error TokenBalanceInsufficient();
