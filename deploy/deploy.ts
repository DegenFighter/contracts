import * as zksync from "zksync-web3";
import * as ethers from "ethers";
import { network } from "hardhat";
import {
  HardhatRuntimeEnvironment,
  HardhatNetworkHDAccountsConfig,
} from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";

import deployedAddresses from "../deployedAddresses.json";

import * as path from "path";
import * as glob from "glob";
const PROJECT_DIR = path.join(__dirname, "..");
const FACETS_SRC_DIR = path.join(PROJECT_DIR, "src", "facets");

const facetNames = glob
  .sync("*Facet.sol", { cwd: FACETS_SRC_DIR })
  .map((a) => path.basename(a).substring(0, a.indexOf(".sol")));

const FacetCutAction = { Add: 0, Replace: 1, Remove: 2 };

function getSelectors(contract: zksync.Contract) {
  const signatures = Object.keys(contract.interface.functions);
  const selectors = signatures.reduce((acc, val) => {
    if (val !== "init(bytes)") {
      acc.push(contract.interface.getSighash(val));
    }
    return acc;
  }, []);
  selectors.contract = contract;
  selectors.remove = remove;
  selectors.get = get;
  return selectors;
}

// used with getSelectors to remove selectors from an array of selectors
// functionNames argument is an array of function signatures
function remove(functionNames) {
  const selectors = this.filter((v) => {
    for (const functionName of functionNames) {
      if (v === this.contract.interface.getSighash(functionName)) {
        return false;
      }
    }
    return true;
  });
  selectors.contract = this.contract;
  selectors.remove = this.remove;
  selectors.get = this.get;
  return selectors;
}

// used with getSelectors to get selectors from an array of selectors
// functionNames argument is an array of function signatures
function get(functionNames) {
  const selectors = this.filter((v) => {
    for (const functionName of functionNames) {
      if (v === this.contract.interface.getSighash(functionName)) {
        return true;
      }
    }
    return false;
  });
  selectors.contract = this.contract;
  selectors.remove = this.remove;
  selectors.get = this.get;
  return selectors;
}

export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script for DegenFighter on zkSync ~`);

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
  const artifact = await deployer.loadArtifact("Proxy");

  const ownerAddress = zkSyncWallet._signerL1().address;
  // Deploy this contract. The returned object will be of a `Contract` type, similarly to ones in `ethers`.
  const diamondContract = await deployer.deploy(artifact, [ownerAddress]);

  // Show the contract info.
  const diamondAddress = diamondContract.address;
  console.log(`${artifact.contractName} was deployed to ${diamondAddress}`);

  deployedAddresses[280] = diamondAddress;

  // deploy InitDiamond
  // InitDiamond provides a function that is called when the diamond is upgraded to initialize state variables
  //   Read about how the diamondCut function works here: https://eips.ethereum.org/EIPS/eip-2535#addingreplacingremoving-functions
  const InitDiamond = await deployer.loadArtifact("InitDiamond");
  const initDiamond = await deployer.deploy(InitDiamond);
  await initDiamond.deployed();
  console.log("InitDiamond deployed:", initDiamond.address);

  // deploy facets
  console.log("");
  console.log("Deploying facets");
  type cutType = {
    facetAddress: string;
    action: number;
    functionSelectors: Array<string>;
  };
  const cut: cutType[] = [];
  for (const FacetName of facetNames) {
    const artifact = await deployer.loadArtifact(FacetName);
    const facet = await deployer.deploy(artifact);
    await facet.deployed();

    console.log(`${artifact.contractName} was deployed to ${facet.address}`);
    cut.push({
      facetAddress: facet.address,
      action: FacetCutAction.Add,
      functionSelectors: getSelectors(facet),
    });
  }

  // upgrade diamond with facets
  console.log("");
  console.log("Diamond Cut:", cut);

  const diamondCutArtifact = await deployer.loadArtifact("DiamondCutFacet");

  const DiamondCutFacet = new zksync.Contract(
    diamondAddress,
    diamondCutArtifact.abi,
    zkSyncWallet
  );

  let tx;
  let receipt;
  // call to init function
  let functionCall = initDiamond.interface.encodeFunctionData("initialize");
  tx = await DiamondCutFacet.diamondCut(cut, initDiamond.address, functionCall);
  console.log("Diamond cut tx: ", tx.hash);
  receipt = await tx.wait();
  if (!receipt.status) {
    throw Error(`Diamond upgrade failed: ${tx.hash}`);
  }
  console.log("Completed diamond cut");

  return diamondAddress;
}
