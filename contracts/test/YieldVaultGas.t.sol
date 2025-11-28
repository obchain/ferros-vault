// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {YieldVault} from "../src/YieldVault.sol";
import {VaultFactory} from "../src/VaultFactory.sol";
import {MockYieldSource} from "../src/strategies/MockYieldSource.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Warm-state gas benchmarks for deposit and withdraw hot paths.
///         All storage slots pre-warmed with a seed deposit before measuring.
contract YieldVaultGasTest is Test {
    YieldVault internal vault;
    MockERC20 internal asset;
    MockYieldSource internal strategy;

    address internal owner  = makeAddr("owner");
    address internal user   = makeAddr("user");

    uint256 constant SEED   = 1_000e6;   // pre-warm deposit
    uint256 constant AMOUNT = 100e6;     // measured deposit/withdraw

    function setUp() public {
        vm.startPrank(owner);

        asset    = new MockERC20("Test USDC", "tUSDC", 6);
        strategy = new MockYieldSource(address(asset), 1_000, owner);

        YieldVault impl    = new YieldVault();
        VaultFactory factory = new VaultFactory(address(impl), owner);
        factory.approveAsset(address(asset));

        address proxy = factory.createVault(
            address(asset), "Ferros Vault USDC", "fUSDC",
            address(strategy), owner, 1_000, owner
        );
        strategy.setVault(proxy);
        vault = YieldVault(proxy);

        vm.stopPrank();

        // Seed deposit — warms all storage slots
        asset.mint(owner, SEED + AMOUNT * 10);
        vm.startPrank(owner);
        asset.approve(address(vault), type(uint256).max);
        vault.deposit(SEED, owner);
        vm.stopPrank();

        // Fund user
        asset.mint(user, AMOUNT * 10);
        vm.prank(user);
        asset.approve(address(vault), type(uint256).max);
    }

    /// @notice Warm deposit — all slots initialised by seed.
    function test_Gas_Deposit_Warm() public {
        vm.prank(user);
        vault.deposit(AMOUNT, user);
    }

    /// @notice Warm withdraw — deposits first, then measures withdraw.
    function test_Gas_Withdraw_Warm() public {
        vm.prank(user);
        vault.deposit(AMOUNT, user);

        uint256 shares = vault.balanceOf(user);
        vm.prank(user);
        vault.redeem(shares, user, user);
    }

    /// @notice Warm redeem (alias path).
    function test_Gas_Redeem_Warm() public {
        vm.prank(user);
        vault.deposit(AMOUNT, user);

        vm.warp(block.timestamp + 1);
        uint256 shares = vault.balanceOf(user);
        vm.prank(user);
        vault.redeem(shares, user, user);
    }
}
