# betting-platform
The EVM smart contract betting platform for DegenFighter.

## Test Locally

Run

```zsh
anvil
```

Then run

```zsh
make deploy-bet
```

The RPC endpoint defaults to: `http:\\127.0.0.1:8545`, chainid: `31337`, sender address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`

The `Bet` contract address is written in json format in `deployedAddresses.json`.