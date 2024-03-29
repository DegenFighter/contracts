import * as zksync from "zksync-web3";
import * as ethers from "ethers";
import { network } from "hardhat";
import {
  HardhatRuntimeEnvironment,
  HardhatNetworkHDAccountsConfig,
} from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";

import deployedAddresses from "../deployedAddresses.json";

export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script to deploy MockTwap contract`);

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

  // Deploy this contract. The returned object will be of a `Contract` type, similarly to ones in `ethers`.
  const MockTwap = await deployer.deploy(artifactMockTwap);
  await MockTwap.deployed();
  // Show the contract info.
  const contractAddress = MockTwap.address;
  console.log(
    `${artifactMockTwap.contractName} was deployed to ${contractAddress}`
  );

  const artifactSettings = await deployer.loadArtifact("SettingsFacet");

  const SettingsFacet = new zksync.Contract(
    deployedAddresses[280],
    artifactSettings.abi,
    zkSyncWallet
  );

  let tx;
  let receipt;
  // call set price oracle on proxy
  tx = await SettingsFacet.setPriceOracle(contractAddress); // address of MockTwap contract
  console.log("setPriceOracle tx: ", tx.hash);
  receipt = await tx.wait();
  if (!receipt.status) {
    throw Error(`setPriceOracle() failed: ${tx.hash}`);
  }
}
