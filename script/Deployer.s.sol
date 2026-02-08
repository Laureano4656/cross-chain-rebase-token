// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {
    IERC20
} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {
    RegistryModuleOwnerCustom
} from "@chainlink/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@chainlink/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

contract TokenDeployer is Script {
    function run() public returns (RebaseToken token) {
        vm.startBroadcast();
        // Deploy RebaseToken
        token = new RebaseToken();

        vm.stopBroadcast();
    }
}

contract PoolDeployer is Script {
    function run(address _token) public returns (RebaseTokenPool pool) {
        CCIPLocalSimulatorFork ccipSimulator = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipSimulator.getNetworkDetails(block.chainid);
        vm.startBroadcast();
        pool = new RebaseTokenPool(
            IERC20(_token), new address[](0), networkDetails.rmnProxyAddress, networkDetails.routerAddress
        );
        vm.stopBroadcast();
    }
}

contract SetPermissions is Script {
    function run(address _token, address _pool) public {
        CCIPLocalSimulatorFork ccipSimulator = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipSimulator.getNetworkDetails(block.chainid);
        vm.startBroadcast();
        IRebaseToken(_token).grantMintAndBurnRole(_pool);
        RegistryModuleOwnerCustom(networkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(_token);
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).acceptAdminRole(_token);
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(_token, _pool);
        vm.stopBroadcast();
    }
}

contract VaultDeployer is Script {
    function run(address _rebaseToken) public returns (Vault vault) {
        vm.startBroadcast();
        // Deploy Vault
        vault = new Vault(IRebaseToken(_rebaseToken));
        IRebaseToken(_rebaseToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}
