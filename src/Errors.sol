// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { BoutState, BoutFighter } from "./Objects.sol";

error NotAllowedError();

error CallerMustBeAdminError();
error CallerMustBeServerError();
error SignerMustBeServerError();
error SignatureExpiredError();

error InvalidFinalizedBoutDataError(uint badSanityCheck);
error BoutInWrongStateError(uint boutId, BoutState state);
error InvalidBettorDataError(uint boutId, BoutFighter fighter);
error InvalidWinnerError(uint boutId, uint8 winner);

error TokenBalanceInsufficient(uint256 userBalance, uint256 amount);
