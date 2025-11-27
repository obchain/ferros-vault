// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {YieldVault} from "../src/YieldVault.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {MockYieldSource} from "../src/strategies/MockYieldSource.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

/// @title Deploy
/// @notice Deploys the full Ferros Vault stack to Ethereum Sepolia.
/// @dev Deploy order:
///      1. MockERC20        — testnet stablecoin (tUSDC, 6 decimals)
///      2. MockYieldSource  — 10% APY simulator, owner = deployer
///      3. YieldVault impl  — logic contract only (no initializer called)
///      4. VaultFactory     — registers impl, owner = deployer
///      5. approveAsset     — whitelist tUSDC
///      6. createVault      — deploys ERC-1967 proxy via factory
///      7. setVault         — binds strategy to vault (one-time, immutable)
///
///      Run:
///        forge script script/Deploy.s.sol \
///          --rpc-url ethereum_sepolia \
///          --broadcast \
///          --verify \
///          -vvvv
contract Deploy is Script {
    // ── Config ────────────────────────────────────────────────────────────────

    string  constant VAULT_NAME          = "Ferros Vault USDC";
    string  constant VAULT_SYMBOL        = "fUSDC";
    uint256 constant INITIAL_APY_BPS     = 1_000;  // 10%
    uint256 constant PERFORMANCE_FEE_BPS = 1_000;  // 10%

    // ── Entry point ───────────────────────────────────────────────────────────

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        console2.log("Deployer        :", deployer);
        console2.log("Chain ID        :", block.chainid);

        vm.startBroadcast(deployerKey);

        // 1. MockERC20 — testnet USDC substitute
        MockERC20 mockToken = new MockERC20("Test USDC", "tUSDC", 6);
        console2.log("MockERC20       :", address(mockToken));

        // 2. MockYieldSource — 10% APY, deployer is owner
        MockYieldSource strategy = new MockYieldSource(
            address(mockToken),
            INITIAL_APY_BPS,
            deployer
        );
        console2.log("MockYieldSource :", address(strategy));

        // 3. YieldVault implementation — logic contract, never initialised directly
        YieldVault vaultImpl = new YieldVault();
        console2.log("YieldVault impl :", address(vaultImpl));

        // 4. VaultFactory — owns impl registry, owner = deployer
        VaultFactory factory = new VaultFactory(address(vaultImpl), deployer);
        console2.log("VaultFactory    :", address(factory));

        // 5. Approve asset before vault creation
        factory.approveAsset(address(mockToken));

        // 6. Create vault proxy via factory
        address vault = factory.createVault(
            address(mockToken),
            VAULT_NAME,
            VAULT_SYMBOL,
            address(strategy),
            deployer,           // feeRecipient = deployer for testnet
            PERFORMANCE_FEE_BPS,
            deployer            // vaultOwner   = deployer for testnet
        );
        console2.log("YieldVault proxy:", vault);

        // 7. Bind strategy to vault (immutable after this call)
        strategy.setVault(vault);
        console2.log("Strategy vault  : set to", vault);

        vm.stopBroadcast();

        // ── Write deployment artefact ─────────────────────────────────────────
        _writeDeployment(
            address(mockToken),
            address(strategy),
            address(vaultImpl),
            address(factory),
            vault,
            block.chainid
        );
    }

    function _writeDeployment(
        address mockToken,
        address strategy,
        address vaultImpl,
        address factory,
        address vault,
        uint256 chainId
    ) internal {
        string memory json = string.concat(
            '{\n',
            '  "chainId": ', vm.toString(chainId), ',\n',
            '  "contracts": {\n',
            '    "MockERC20": "',       vm.toString(mockToken),  '",\n',
            '    "MockYieldSource": "', vm.toString(strategy),   '",\n',
            '    "YieldVaultImpl": "',  vm.toString(vaultImpl),  '",\n',
            '    "VaultFactory": "',    vm.toString(factory),    '",\n',
            '    "YieldVault": "',      vm.toString(vault),      '"\n',
            '  }\n',
            '}'
        );

        string memory path = string.concat(
            vm.projectRoot(),
            "/../deployments/",
            vm.toString(chainId),
            ".json"
        );

        vm.writeFile(path, json);
        console2.log("Deployment JSON :", path);
    }
}
