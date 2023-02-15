import * as zksync from "zksync-web3";
import * as ethers from "ethers";
import { network } from "hardhat";
import {
  HardhatRuntimeEnvironment,
  HardhatNetworkHDAccountsConfig,
} from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";

// An example of a deploy script that will deploy and call a simple contract.
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script for the Greeter contract`);

  const zkSyncProvider = new zksync.Provider(
    "https://zksync2-testnet.zksync.dev/"
  );
  const ethProvider = ethers.getDefaultProvider("goerli");
  // Initialize the wallet.
  const accounts = network.config.accounts as HardhatNetworkHDAccountsConfig;
  const zkSyncWallet = zksync.Wallet.fromMnemonic(accounts.mnemonic)
    .connect(zkSyncProvider)
    .connectToL1(ethProvider);

  // Deposit some funds to L2 in order to be able to perform L2 transactions.
  //   const depositAmount = ethers.utils.parseEther("0.001");
  //   const depositHandle = await deployer.zkWallet.deposit({
  //     to: deployer.zkWallet.address,
  //     token: utils.ETH_ADDRESS,
  //     amount: depositAmount,
  //   });
  //   // Wait until the deposit is processed on zkSync
  //   await depositHandle.wait();

  // Create deployer object and load the artifact of the contract we want to deploy.

  const deployer = new Deployer(hre, zkSyncWallet);
  const artifact = await deployer.loadArtifact("Greeter");

  // Deploy this contract. The returned object will be of a `Contract` type, similarly to ones in `ethers`.
  // `greeting` is an argument for contract constructor.
  const greeting = "";
  const greeterContract = await deployer.deploy(artifact, [greeting]);

  // Show the contract info.
  const contractAddress = greeterContract.address;
  console.log(`${artifact.contractName} was deployed to ${contractAddress}`);

  // Call the deployed contract.
  const greetingFromContract = await greeterContract.greet();
  if (greetingFromContract == greeting) {
    console.log(`Contract greets us with ${greeting}!`);
  } else {
    console.error(
      `Contract said something unexpected: ${greetingFromContract}`
    );
  }

  // Edit the greeting of the contract
  const newGreeting = "Hey guys";
  const setNewGreetingHandle = await greeterContract.setGreeting(newGreeting);
  await setNewGreetingHandle.wait();

  const newGreetingFromContract = await greeterContract.greet();
  if (newGreetingFromContract == newGreeting) {
    console.log(`Contract greets us with ${newGreeting}!`);
  } else {
    console.error(
      `Contract said something unexpected: ${newGreetingFromContract}`
    );
  }
}
