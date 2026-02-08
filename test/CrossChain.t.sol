// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {
    RegistryModuleOwnerCustom
} from "@chainlink/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {Vault} from "../src/Vault.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {
    IERC20
} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {TokenAdminRegistry} from "@chainlink/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "@chainlink/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@chainlink/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

contract CrossChainTest is Test {
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    uint256 public constant SEND_VALUE = 1e5;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    RebaseToken private sepoliaRebaseToken;
    RebaseToken private arbSepoliaRebaseToken;

    Vault private vault;

    RebaseTokenPool private sepoliaPool;
    RebaseTokenPool private arbSepoliaPool;

    CCIPLocalSimulatorFork private ccipSimulator;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia-eth");
        arbSepoliaFork = vm.createFork("arb-sepolia");
        ccipSimulator = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipSimulator));

        sepoliaNetworkDetails = ccipSimulator.getNetworkDetails(block.chainid);

        // 1. Deploy and configure on Sepolia
        vm.startPrank(owner);
        sepoliaRebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaRebaseToken)));
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaRebaseToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );
        sepoliaRebaseToken.grantMintAndBurnRole(address(vault));
        sepoliaRebaseToken.grantMintAndBurnRole(address(sepoliaPool));

        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(sepoliaRebaseToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaRebaseToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(sepoliaRebaseToken), address(sepoliaPool));

        vm.stopPrank();

        // 2. Deploy and configure on Arbitrum Sepolia
        vm.selectFork(arbSepoliaFork);
        arbSepoliaNetworkDetails = ccipSimulator.getNetworkDetails(block.chainid);
        vm.startPrank(owner);
        arbSepoliaRebaseToken = new RebaseToken();
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaRebaseToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );
        arbSepoliaRebaseToken.grantMintAndBurnRole(address(arbSepoliaPool));
        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(arbSepoliaRebaseToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(arbSepoliaRebaseToken));

        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(arbSepoliaRebaseToken), address(arbSepoliaPool));
        vm.stopPrank();
        configureTokenPool(
            sepoliaFork,
            address(sepoliaPool),
            arbSepoliaNetworkDetails.chainSelector,
            address(arbSepoliaPool),
            address(arbSepoliaRebaseToken)
        );
        configureTokenPool(
            arbSepoliaFork,
            address(arbSepoliaPool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaPool),
            address(sepoliaRebaseToken)
        );
    }

    function configureTokenPool(
        uint256 fork,
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteToken
    ) public {
        vm.selectFork(fork);
        vm.prank(owner);

        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,
            remotePoolAddress: abi.encode(remotePool),
            remoteTokenAddress: abi.encode(remoteToken),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, rate: 0, capacity: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, rate: 0, capacity: 0})
        });
        TokenPool(localPool).applyChainUpdates(chainsToAdd);
    }

    function testBridgeAllTokens() public {
        vm.selectFork(sepoliaFork);
        vm.deal(user, SEND_VALUE);
        vm.prank(user);
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        assertEq(sepoliaRebaseToken.balanceOf(user), SEND_VALUE);
        bridgeTokens(
            SEND_VALUE,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sepoliaRebaseToken,
            arbSepoliaRebaseToken
        );
        vm.selectFork(arbSepoliaFork);
        vm.warp(block.timestamp + 20 minutes);
        bridgeTokens(
            arbSepoliaRebaseToken.balanceOf(user),
            arbSepoliaFork,
            sepoliaFork,
            arbSepoliaNetworkDetails,
            sepoliaNetworkDetails,
            arbSepoliaRebaseToken,
            sepoliaRebaseToken
        );
    }

    function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public {
        vm.selectFork(localFork);
        //struct EVM2AnyMessage {
        //     bytes receiver; // abi.encode(receiver address) for dest EVM chains
        //     bytes data; // Data payload
        //     EVMTokenAmount[] tokenAmounts; // Token transfers
        //     address feeToken; // Address of feeToken. address(0) means you will send msg.value.
        //     bytes extraArgs; // Populate this with _argsToBytes(EVMExtraArgsV2)
        //   }

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: localNetworkDetails.linkAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 500_000}))
        });
        uint256 fee =
            IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);
        ccipSimulator.requestLinkFromFaucet(user, fee);

        vm.prank(user);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);
        vm.prank(user);
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);

        uint256 localBalanceBefore = localToken.balanceOf(user);
        console.log("Local balance before:", localBalanceBefore);
        vm.prank(user);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);

        uint256 localBalanceAfter = localToken.balanceOf(user);
        assertEq(localBalanceAfter, localBalanceBefore - amountToBridge);
        uint256 localUserInterestRate = localToken.getUserInterestRate(user);

        vm.selectFork(remoteFork);
        vm.warp(block.timestamp + 20 minutes); // Fast forward to ensure message is processed
        uint256 remoteBalanceBefore = remoteToken.balanceOf(user);
        vm.selectFork(localFork);
        ccipSimulator.switchChainAndRouteMessage(remoteFork);

        assertEq(remoteToken.balanceOf(user), remoteBalanceBefore + amountToBridge);
        uint256 remoteUserInterestRate = remoteToken.getUserInterestRate(user);
        assertEq(localUserInterestRate, remoteUserInterestRate);
    }
}
