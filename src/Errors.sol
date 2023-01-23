// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { BoutState, BoutFighter } from "./Objects.sol";

error NotAllowedError();

error CallerMustBeAdminError();
error CallerMustBeServerError();
error SignerMustBeServerError();
error SignatureExpiredError();

error BoutInWrongStateError(uint boutNum, BoutState state);
error MinimumBetAmountError(uint boutNum, address supporter, uint amount);
error InvalidBetTargetError(uint boutNum, address supporter, uint8 br);
error InvalidWinnerError(uint boutNum, BoutFighter winner);

error TokenBalanceInsufficient(uint256 userBalance, uint256 amount);
