-include .env

help:
	@echo "Usage:"
	@echo " Make deploy [ARGS]..."

build:; forge build
install:; forge install Cyfrin/foundry-devops --no-commit &&
	forge install transmissions11/solmate && forge install smartcontractkit/chainlink-brownie-contracts
	&& forge install OpenZeppelin/openzeppelin-contracts

testRaffle:; forge test

NETWORK_ARGS := --rpc-url http://127.0.0.1:8545 --private-key $(PRIVATE_KEY_ANVIL) --broadcast -vvv 

ifeq ($(findstring --network sepolia, $(ARGS)), --network sepolia)
	NETWORK_ARGS:=--rpc-url $(RPC_ALCHEMY_SEPOLIA_TESTNET) --private-key $(RPRIVATE_KEY) --broadcast -vvvv --verify --etherscan-api-key $(ETHERSCAN_API_KEY)
endif

deployBasicNft:
	@forge script script/DeployBasicNft.s.sol:DeployBasicNft $(NETWORK_ARGS)

deployMoodNft:
	@forge script script/DeployMoodNft.s.sol:DeployMoodNft $(NETWORK_ARGS)

mint:
	@forge script script/BasicNftInteractions.s.sol:MintBasicNft $(NETWORK_ARGS)

mintMoodNft:
	@forge script script/MoodNftInteractions.s.sol:MintMoodNft $(NETWORK_ARGS)