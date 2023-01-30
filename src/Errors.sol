// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17 <0.9;

import { BoutState, BoutFighter } from "./Objects.sol";

error NotAllowedError();

error CallerMustBeAdminError();
error CallerMustBeServerError();
error SignerMustBeServerError();
error SignatureExpiredError();

error BoutInWrongStateError(uint boutId, BoutState state);
error BoutExpiredError(uint boutId, uint expiryTime);
error PotMismatchError(uint boutId, uint fighterAPot, uint fighterBPot, uint totalPot);
error MinimumBetAmountError(uint boutId, address bettor, uint amount);
error InvalidBetTargetError(uint boutId, address bettor, uint8 br);
error InvalidWinnerError(uint boutId, BoutFighter winner);

error TokenBalanceInsufficient(uint256 userBalance, uint256 amount);
