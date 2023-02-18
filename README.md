[![build](https://github.com/DegenFighter/contracts/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/DegenFighter/contracts/actions/workflows/ci.yml)

# DegenFighter contracts

The EVM smart contracts for DegenFighter.

## Development

Install:

- Install [foundry](https://github.com/foundry-rs/foundry/blob/master/README.md)
- Run `foundryup`
- Run `forge install foundry-rs/forge-std`
- Run `npm i`
- Run `git submodule update --init --recursive`
- Run `cp .env.example .env` and set the following within:

* `export LOCAL_RPC_URL=http://localhost:8545`
* `export ALCHEMY_ETH_GOERLI_RPC_URL=...`
* `export ETHERSCAN_API_KEY=...`

### Test Locally

Run in a new terminal:

```zsh
anvil
```

Then run in a separate terminal:

```zsh
make prep-build
make build
make deploy-local
```

The RPC endpoint defaults to: `http://127.0.0.1:8545`, chainid: `31337`, sender address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`

The contact addresses will be output as follows:

```zsh
  Address[proxy]:  0x5FbDB2315678afecb367f032d93F642f64180aa3
  Address[memeToken]:  0x238213078DbD09f2D15F4c14c02300FA1b2A81BB
  Address[multicall]:  0xd85BdcdaE4db1FAEB8eF93331525FE68D7C8B3f0
```

### Deployment

1. Enter the deployment mnemonic into `mnemonic.txt`
1. Deploy a new diamond on Goerli:

#### To Goerli Testnet

```zsh
make deploy-goerli newDiamond=true initNewDiamond=true facetAction=0
```

#### To zkSync era testnet

First, compile contracts with zksolc

```zsh
make build-zksync
```

Then, run the deploy script

```zsh
deploy-zksync
```

## Publish NPM package

Run `make release`. This will update the NPM version, the `CHANGELOG` and trigger Github Actions to publish a new NPM package.

The current package is always available at: [DegenFighter Github](https://github.com/DegenFighter/contracts/pkgs/npm/contracts)
