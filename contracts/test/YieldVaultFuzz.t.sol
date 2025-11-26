// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {YieldVault} from "../src/YieldVault.sol";
import {MockYieldSource} from "../src/strategies/MockYieldSource.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Fuzz Token", "FZZ") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract YieldVaultFuzzTest is Test {
    MockERC20 internal asset;
    MockYieldSource internal yieldSource;
    YieldVault internal vault;

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");
    address internal treasury = makeAddr("treasury");

    function setUp() public {
        asset = new MockERC20();
        yieldSource = new MockYieldSource(address(asset), 1_000, owner); // 10% APY

        YieldVault impl = new YieldVault();
        bytes memory initData = abi.encodeWithSelector(
            YieldVault.initialize.selector,
            address(asset),
            "Fuzz Vault",
            "fvFUZZ",
            address(yieldSource),
            treasury,
            uint256(1_000), // 10% perf fee
            owner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        vault = YieldVault(address(proxy));

        vm.prank(owner);
        yieldSource.setVault(address(vault));
    }

    function _deposit(uint256 assets) internal returns (uint256 shares) {
        asset.mint(user, assets);
        vm.startPrank(user);
        asset.approve(address(vault), assets);
        shares = vault.deposit(assets, user);
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Invariant: deposit always mints > 0 shares when assets > 0
    // -------------------------------------------------------------------------

    function testFuzz_Deposit_AlwaysMintsShares(uint256 assets) public {
        assets = bound(assets, 1e6, type(uint80).max);
        uint256 shares = _deposit(assets);
        assertGt(shares, 0);
    }

    // -------------------------------------------------------------------------
    // Invariant: assets forwarded to strategy equal deposit amount
    // -------------------------------------------------------------------------

    function testFuzz_Deposit_FullyForwardedToStrategy(uint256 assets) public {
        assets = bound(assets, 1e6, type(uint80).max);
        _deposit(assets);
        assertEq(asset.balanceOf(address(yieldSource)), assets);
    }

    // -------------------------------------------------------------------------
    // Invariant: withdraw never returns more than deposited
    // -------------------------------------------------------------------------

    function testFuzz_Withdraw_NeverExceedsDeposit(uint256 assets) public {
        assets = bound(assets, 1e6, type(uint80).max);
        _deposit(assets);

        uint256 maxWithdraw = vault.maxWithdraw(user);
        if (maxWithdraw == 0) return;

        uint256 balBefore = asset.balanceOf(user);
        vm.prank(user);
        vault.withdraw(maxWithdraw, user, user);

        assertLe(asset.balanceOf(user) - balBefore, assets + 1);
    }

    // -------------------------------------------------------------------------
    // Invariant: convertToAssets(convertToShares(x)) within 1 wei
    // -------------------------------------------------------------------------

    function testFuzz_ConvertRoundTrip_WithinOneWei(uint256 assets) public {
        _deposit(1_000e18); // seed vault first
        assets = bound(assets, 1e6, type(uint80).max);
        uint256 shares = vault.convertToShares(assets);
        uint256 back = vault.convertToAssets(shares);
        assertLe(back, assets + 1);
    }

    // -------------------------------------------------------------------------
    // Invariant: totalAssets never decreases without withdrawal
    // -------------------------------------------------------------------------

    function testFuzz_TotalAssets_NeverDecreasesWithoutWithdraw(uint256 assets, uint256 elapsed) public {
        assets = bound(assets, 1e6, type(uint80).max);
        elapsed = bound(elapsed, 1, 365 days);

        _deposit(assets);
        uint256 before = vault.totalAssets();

        vm.warp(block.timestamp + elapsed);
        assertGe(vault.totalAssets(), before);
    }

    // -------------------------------------------------------------------------
    // Invariant: performance fee never exceeds gain
    // -------------------------------------------------------------------------

    function testFuzz_PerformanceFee_NeverExceedsGain(uint256 assets, uint256 elapsed) public {
        assets = bound(assets, 1e6, type(uint80).max);
        elapsed = bound(elapsed, 1 days, 365 days);

        _deposit(assets);
        vm.warp(block.timestamp + elapsed);
        yieldSource.accrueYield();

        uint256 gain = vault.totalAssets() - vault.lastHarvestAssets();
        vm.prank(owner);
        vault.harvest();

        uint256 feeAssets = vault.convertToAssets(vault.balanceOf(treasury));
        assertLe(feeAssets, gain + 1);
    }

    // -------------------------------------------------------------------------
    // Invariant: redeem returns non-zero assets for non-zero shares
    // -------------------------------------------------------------------------

    function testFuzz_Redeem_AlwaysReturnsAssets(uint256 assets) public {
        assets = bound(assets, 1e6, type(uint80).max);
        uint256 shares = _deposit(assets);

        vm.prank(user);
        uint256 received = vault.redeem(shares, user, user);
        assertGt(received, 0);
    }

    // -------------------------------------------------------------------------
    // Invariant: fee config change never affects user principal
    // -------------------------------------------------------------------------

    function testFuzz_FeeChange_DoesNotAffectPrincipal(uint256 assets, uint256 newFee) public {
        assets = bound(assets, 1e6, type(uint80).max);
        newFee = bound(newFee, 0, 3_000);

        uint256 shares = _deposit(assets);
        uint256 assetsBefore = vault.convertToAssets(shares);

        vm.prank(owner);
        vault.setPerformanceFeeBps(newFee);

        uint256 assetsAfter = vault.convertToAssets(shares);
        assertEq(assetsAfter, assetsBefore, "fee config change must not alter share value");
    }
}
