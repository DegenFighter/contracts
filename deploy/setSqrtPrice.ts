import * as zksync from "zksync-web3";
import * as ethers from "ethers";
import { network } from "hardhat";
import {
  HardhatRuntimeEnvironment,
  HardhatNetworkHDAccountsConfig,
} from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";

export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running script to set sqrt price of MockTwap`);

  const zkSyncProvider = new zksync.Provider(
    "https://zksync2-testnet.zksync.dev/"
  );
  const ethProvider = ethers.getDefaultProvider("goerli");
  // Initialize the wallet.
  const accounts = network.config.accounts as HardhatNetworkHDAccountsConfig;
  const zkSyncWallet = zksync.Wallet.fromMnemonic(accounts.mnemonic)
    .connect(zkSyncProvider)
    .connectToL1(ethProvider);

  // Create deployer object and load the artifact of the contract we want to deploy.
  const deployer = new Deployer(hre, zkSyncWallet);
  const artifactMockTwap = await deployer.loadArtifact("MockTwap");

  const mockTwapAddress = "0x7984a52e362be5293b7430d88af0d32ba7a3aec4";
  const MockTwap = new zksync.Contract(
    mockTwapAddress,
    artifactMockTwap.abi,
    zkSyncWallet
  );

  let tx;
  let receipt;
  const ten18 = ethers.BigNumber.from(10).pow(18);
  const price = ethers.BigNumber.from(1625).mul(ten18);
  tx = await MockTwap.setSqrtPriceX96(price);
  console.log("setSqrtPriceX96 tx: ", tx.hash);
  receipt = await tx.wait();
  if (!receipt.status) {
    throw Error(`setSqrtPriceX96() failed: ${tx.hash}`);
  }
}
