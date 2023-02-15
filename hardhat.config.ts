import "@matterlabs/hardhat-zksync-deploy";
import "@matterlabs/hardhat-zksync-solc";
import "hardhat-gas-reporter";
import "@nomicfoundation/hardhat-foundry";

import * as dotenv from "dotenv";
import { resolve } from "path";
dotenv.config({ path: resolve(__dirname, `./.env`) });

module.exports = {
  paths: {
    artifacts: `./artifacts`,
    cache: `./cache`,
    sources: `src`,
    tests: `test`,
  },
  zksolc: {
    version: "1.3.1",
    compilerSource: "binary",
    settings: {},
  },
  defaultNetwork: "zkTestnet",
  networks: {
    hardhat: {
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
      allowUnlimitedContractSize: true,
      chainId: 31337,
      zksync: true,
    },
    zkTestnet: {
      accounts: {
        mnemonic: process.env.MNEMONIC,
        initialIndex: 0,
        count: 20,
        path: `m/44'/60'/0'/0`,
        accountsBalance: "",
        passphrase: "",
      },
      chainId: 280,
      url: `https://zksync2-testnet.zksync.dev`, // URL of the zkSync network RPC
      ethNetwork: process.env.ALCHEMY_ETH_GOERLI_RPC_URL,
      zksync: true,
    },
  },
  gasReporter: {
    currency: `USD`,
    enabled: true,
    excludeContracts: [`./test`],
    src: `./src`,
  },
  solidity: {
    version: "0.8.17",
  },
};
