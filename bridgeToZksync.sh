#!/bin/bash

# Define constants 
AMOUNT=100000

DEFAULT_ZKSYNC_LOCAL_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
DEFAULT_ZKSYNC_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

ZKSYNC_REGISTRY_MODULE_OWNER_CUSTOM="0x3139687Ee9938422F57933C3CDB3E21EE43c4d0F"
ZKSYNC_TOKEN_ADMIN_REGISTRY="0xc7777f12258014866c677Bdb679D0b007405b7DF"
ZKSYNC_ROUTER="0xA1fdA8aa9A8C4b945C45aD30647b01f07D7A0B16"
ZKSYNC_RNM_PROXY_ADDRESS="0x3DA20FD3D8a8f8c1f1A5fD03648147143608C467"
ZKSYNC_SEPOLIA_CHAIN_SELECTOR="6898391096552792247"
ZKSYNC_LINK_ADDRESS="0x23A1aFD896c8c8876AF46aDc38521f4432658d1e"

SEPOLIA_REGISTRY_MODULE_OWNER_CUSTOM="0x62e731218d0D47305aba2BE3751E7EE9E5520790"
SEPOLIA_TOKEN_ADMIN_REGISTRY="0x95F29FEE11c5C55d26cCcf1DB6772DE953B37B82"
SEPOLIA_ROUTER="0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59"
SEPOLIA_RNM_PROXY_ADDRESS="0xba3f6251de62dED61Ff98590cB2fDf6871FbB991"
SEPOLIA_CHAIN_SELECTOR="16015286601757825753"
SEPOLIA_LINK_ADDRESS="0x779877A7B0D9E8603169DdbD7836e478b4624789"



ZKSYNC_REBASE_TOKEN_ADDRESS="0xf58d546030e23328Fe5A9D065987B33aEAE18b5A"
ZKSYNC_POOL_ADDRESS="0x268aA0efaFdf6B7d25D432698CF5FEF5FF5F6348"
# Compile and deploy the Rebase Token contract
# foundryup-zksync
source .env
forge build --zksync
# echo "Compiling and deploying the Rebase Token contract on ZKsync..."
# ZKSYNC_REBASE_TOKEN_ADDRESS=$(forge create src/RebaseToken.sol:RebaseToken --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account default --zksync --legacy --broadcast  | awk '/Deployed to:/ {print $3}')
# echo "ZKsync rebase token address: $ZKSYNC_REBASE_TOKEN_ADDRESS"

# # Compile and deploy the pool contract
# echo "Compiling and deploying the pool contract on ZKsync..."
# ZKSYNC_POOL_ADDRESS=$(forge create src/RebaseTokenPool.sol:RebaseTokenPool --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account default --zksync --legacy --broadcast --constructor-args ${ZKSYNC_REBASE_TOKEN_ADDRESS} [] ${ZKSYNC_RNM_PROXY_ADDRESS} ${ZKSYNC_ROUTER} | awk '/Deployed to:/ {print $3}')
# echo "Pool address: $ZKSYNC_POOL_ADDRESS"

# # Set the permissions for the pool contract
# echo "Setting the permissions for the pool contract on ZKsync..."
# cast send ${ZKSYNC_REBASE_TOKEN_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account default "grantMintAndBurnRole(address)" ${ZKSYNC_POOL_ADDRESS}
# echo "Pool permissions set"

# # Set the CCIP roles and permissions
# echo "Setting the CCIP roles and permissions on ZKsync..."
# cast send ${ZKSYNC_REGISTRY_MODULE_OWNER_CUSTOM} "registerAdminViaOwner(address)" ${ZKSYNC_REBASE_TOKEN_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account default
# cast send ${ZKSYNC_TOKEN_ADMIN_REGISTRY} "acceptAdminRole(address)" ${ZKSYNC_REBASE_TOKEN_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account default
# cast send ${ZKSYNC_TOKEN_ADMIN_REGISTRY} "setPool(address,address)" ${ZKSYNC_REBASE_TOKEN_ADDRESS} ${ZKSYNC_POOL_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account default
# echo "CCIP roles and permissions set"

# # 2. On Sepolia!

# echo "Running the script to deploy the contracts on Sepolia..."
# forge script ./script/Deployer.s.sol:TokenDeployer --rpc-url ${SEPOLIA_RPC_URL} --account default --broadcast 
# echo "Token Contract deployed on Sepolia"

# Extract the addresses from the output
#SEPOLIA_REBASE_TOKEN_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "RebaseToken") | .contractAddress' ./broadcast/Deployer.s.sol/11155111/run-latest.json)

SEPOLIA_REBASE_TOKEN_ADDRESS="0x6c4a0429ef1e29c17aff310841ee019f9b1cc65f"
echo "Sepolia rebase token address: $SEPOLIA_REBASE_TOKEN_ADDRESS"

# echo "Deploying the pool on Sepolia..."
# forge script ./script/Deployer.s.sol:PoolDeployer --rpc-url ${SEPOLIA_RPC_URL} --account default --broadcast --sig "run(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} 
# SEPOLIA_POOL_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "RebaseTokenPool") | .contractAddress' ./broadcast/Deployer.s.sol/11155111/run-latest.json)

SEPOLIA_POOL_ADDRESS="0xbe757039fe37613751b1713a6327863081e21ca0"

# echo "Giving permissions to the pool on Sepolia..."

# forge script ./script/Deployer.s.sol:SetPermissions --rpc-url ${SEPOLIA_RPC_URL} --account default --broadcast --sig "run(address,address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${SEPOLIA_POOL_ADDRESS}

echo "Sepolia rebase token address: $SEPOLIA_REBASE_TOKEN_ADDRESS"
echo "Sepolia pool address: $SEPOLIA_POOL_ADDRESS"

# Deploy the vault 
# echo "Deploying the vault on Sepolia..."
# forge script ./script/Deployer.s.sol:VaultDeployer --rpc-url ${SEPOLIA_RPC_URL} --account default --broadcast --sig "run(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} 
# VAULT_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "Vault") | .contractAddress' ./broadcast/Deployer.s.sol/11155111/run-latest.json)

VAULT_ADDRESS="0x965c048095353579b6ee6eedf0f1ca9f56a6bde4"
echo "Vault address: $VAULT_ADDRESS"

# Configure the pool on Sepolia
echo "Configuring the pool on Sepolia..."
# uint64 remoteChainSelector,
#         address remotePoolAddress, /
#         address remoteTokenAddress, /
#         bool outboundRateLimiterIsEnabled, false 
#         uint128 outboundRateLimiterCapacity, 0
#         uint128 outboundRateLimiterRate, 0
#         bool inboundRateLimiterIsEnabled, false 
#         uint128 inboundRateLimiterCapacity, 0 
#         uint128 inboundRateLimiterRate 0 
# forge script ./script/ConfigurePool.s.sol:ConfigurePoolScript --rpc-url ${SEPOLIA_RPC_URL} --account default --broadcast --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${SEPOLIA_POOL_ADDRESS} ${ZKSYNC_SEPOLIA_CHAIN_SELECTOR} ${ZKSYNC_POOL_ADDRESS} ${ZKSYNC_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0

# # Deposit funds to the vault
# echo "Depositing funds to the vault on Sepolia..."
# cast send ${VAULT_ADDRESS} --value ${AMOUNT} --rpc-url ${SEPOLIA_RPC_URL} --account default "deposit()"

# # Wait a beat for some interest to accrue
ENCODED_POOL=$(cast abi-encode "f(address)" ${SEPOLIA_POOL_ADDRESS})
ENCODED_TOKEN=$(cast abi-encode "f(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS})

# Send the transaction
# Note: The signature takes one argument: An array "[]" of the tuple defined above.
# cast send ${ZKSYNC_POOL_ADDRESS} \
#   --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} \
#   --account default \
#   "applyChainUpdates((uint64,bool,bytes,bytes,(bool,uint128,uint128),(bool,uint128,uint128))[])" \
#   "[(${SEPOLIA_CHAIN_SELECTOR},true,${ENCODED_POOL},${ENCODED_TOKEN},(false,0,0),(false,0,0))]"
# # # Configure the pool on ZKsync
# echo "Configuring the pool on ZKsync..."
# cast send ${ZKSYNC_POOL_ADDRESS}  --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account default "applyChainUpdates((uint64,bytes[],bytes,(bool,uint128,uint128),(bool,uint128,uint128))[])" "[${SEPOLIA_CHAIN_SELECTOR}]" "[(${SEPOLIA_CHAIN_SELECTOR},[$(cast abi-encode "f(address)" ${SEPOLIA_POOL_ADDRESS})],$(cast abi-encode "f(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS}),(false,0,0),(false,0,0))]"

# # Bridge the funds using the script to zksync 
# echo "Bridging the funds using the script to ZKsync..."
# SEPOLIA_BALANCE_BEFORE=$(cast balance $(cast wallet address --account default) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
# echo "Sepolia balance before bridging: $SEPOLIA_BALANCE_BEFORE"
# forge script ./script/BridgeTokens.s.sol:BridgeTokensScript --rpc-url ${SEPOLIA_RPC_URL} --account default --broadcast --sig "run(address,uint64,address,uint256,address,address)" $(cast wallet address --account default) ${ZKSYNC_SEPOLIA_CHAIN_SELECTOR} ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${AMOUNT} ${SEPOLIA_LINK_ADDRESS} ${SEPOLIA_ROUTER}
# echo "Funds bridged to ZKsync"
SEPOLIA_BALANCE_AFTER=$(cast balance $(cast wallet address --account default) --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance after bridging: $SEPOLIA_BALANCE_AFTER"

ZKSYNC_BALANCE=$(cast balance $(cast wallet address --account default) --erc20 ${ZKSYNC_REBASE_TOKEN_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL})
echo "ZKsync balance after bridging: $ZKSYNC_BALANCE"