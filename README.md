# betting-platform

The EVM smart contract betting platform for DegenFighter.

## Development

Install:

- Install [foundry](https://github.com/foundry-rs/foundry/blob/master/README.md)
- Run `foundryup`
- Run `npm i`
- Run `git submodule update --init --recursive`
- Run `cp .env.example .env` and set `export LOCAL_RPC_URL=http://localhost:8545` inside `.env`

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

The RPC endpoint defaults to: `http:\\127.0.0.1:8545`, chainid: `31337`, sender address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`

The `Proxy` contract address is written in json format in `deployedAddresses.json`.
