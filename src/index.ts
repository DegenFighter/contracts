import { ContractInterface } from "@ethersproject/contracts";

const { abi: ProxyAbi } = require("../out/IProxy.sol/IProxy.json");
const { abi: IERC20Abi } = require("../out/IERC20.sol/IERC20.json");
const { abi: IERC173Abi } = require("../out/IERC173.sol/IERC173.json");

export const abi = {
  Proxy: ProxyAbi as ContractInterface,
  IERC20: IERC20Abi as ContractInterface,
  IERC173: IERC173Abi as ContractInterface,
};
