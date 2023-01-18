# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

.DEFAULT_GOAL := help
.PHONY: help
help:		## display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# inspiration from Patrick Collins: https://github.com/smartcontractkit/foundry-starter-kit/blob/main/Makefile
# wip (don't use "all" yet)
all: clean remove install update build

clean: ## clean the repo
	forge clean

update: ## update rust, foundry and submodules
	rustup update && foundryup && forge update

formatsol: ## run prettier on src, test and scripts
	yarn run prettier

lintsol: ## run prettier and solhint
	yarn run lint

devnet: ## run development node
	anvil -f ${ALCHEMY_ETH_MAINNET_RPC_URL} \
		--fork-block-number 15078000 \
		-vvvv

prep-build:
	@echo "preparing build"
	node ./script/prep-build.js

build: ## forge build
	forge build --names --sizes && node ./script/write-index.js && yarn tsc

b: build

bscript: ## build forge scripts
	forge build --root . --contracts script/

.PHONY: test
test: ## forge test local, alias t
	forge test
t: test

tt: ## forge test local -vv
	forge test -vv

ttt: ## forge test local -vvv
	forge test -vvv
	
tttt: ## forge test local -vvvv
	forge test -vvvv

gas: ## gas snapshot
	forge snapshot --check

gasforksnap: ## gas snapshot mainnet fork
	forge snapshot --snap .gas-snapshot \
		-f ${ALCHEMY_ETH_MAINNET_RPC_URL} \
		--fork-block-number 15078000

gasforkcheck: ## gas check mainnet fork
	forge snapshot --check \
		-f ${ALCHEMY_ETH_MAINNET_RPC_URL} \
		--fork-block-number 15078000 \
		--via-ir

gasforkdiff: ## gas snapshot diff mainnet fork
	forge snapshot --diff \
		-f ${ALCHEMY_ETH_MAINNET_RPC_URL} \
		--fork-block-number 15078000 \
		--via-ir

cov: ## coverage report -vvv
	forge coverage -vvv

coverage: ## coverage report (lcov), filtered for CI
	forge coverage -vvv --report lcov --via-ir && node ./cli-tools/filter-lcov.js

lcov: ## coverage report (lcov)
	forge coverage --report lcov --via-ir

lcov-fork: ## coverage report (lcov) for mainnet fork
	forge coverage --report lcov \
		-f ${ALCHEMY_ETH_MAINNET_RPC_URL} \
		--fork-block-number 15078000 \
		--via-ir

anvil-fork: ## fork goerli locally with anvil
	anvil -f ${ALCHEMY_ETH_GOERLI_RPC_URL}

deploy-local: ## deploy contracts to local node with sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
	forge script DeployProxy \
		-f http:\\127.0.0.1:8545 \
		--sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
		--broadcast \
		-vvvv 

# Deployment defaults
facetsToCutIn="[]"
newDiamond=false
initNewDiamond=false
facetAction=1
senderAddress=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

deploy-polygon: ## deploy contracts to polygon with sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
	@forge script SmartDeploy \
		-s "smartDeploy(bool, bool, uint8, string[] memory)" ${newDiamond} ${initNewDiamond} ${facetAction} ${facetsToCutIn} \
		-f ${ALCHEMY_ETH_GOERLI_RPC_URL} \
		--chain-id 5 \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--sender ${senderAddress} \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
		-vv \
		--ffi \
		--broadcast \
		--verify --delay 30 --retries 10

deploy-sim: ## simulate smart deploy to polygon
	forge script SmartDeploy \
		-s "smartDeploy(bool, bool, uint8, string[] memory)" ${newDiamond} ${initNewDiamond} ${facetAction} ${facetsToCutIn} \
		-f ${ALCHEMY_POLYGON_RPC_URL} \
		--chain-id 137 \
		--etherscan-api-key ${ETHERSCAN_API_KEY} \
		--sender ${senderAddress} \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
		-vv \
		--ffi

release: build
	yarn standard-version && git push --follow-tags