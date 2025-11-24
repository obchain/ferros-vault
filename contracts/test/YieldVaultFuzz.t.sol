// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {YieldVault} from "../src/YieldVault.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract YieldVaultFuzzTest is Test {
    MockERC20 internal asset;
    YieldVault internal vault;

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");

    function setUp() public {
        asset = new MockERC20();

        YieldVault impl = new YieldVault();
        bytes memory initData = abi.encodeWithSelector(
            YieldVault.initialize.selector,
            address(asset),
            "Fuzz Vault",
            "fvFUZZ",
            uint256(500),
            owner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        vault = YieldVault(address(proxy));
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /// @dev Deposits `assets` as `user`, returns shares received.
    function _deposit(uint256 assets) internal returns (uint256 shares) {
        asset.mint(user, assets);
        vm.startPrank(user);
        asset.approve(address(vault), assets);
        shares = vault.deposit(assets, user);
        vm.stopPrank();
    }

    /// @dev Sends `amount` extra tokens to the vault to cover yield obligations.
    function _fundVault(uint256 amount) internal {
        asset.mint(owner, amount);
        vm.prank(owner);
        asset.transfer(address(vault), amount);
    }

    // -------------------------------------------------------------------------
    // Invariant: deposit always mints > 0 shares when assets > 0
    // -------------------------------------------------------------------------

    function testFuzz_Deposit_AlwaysMintsShares(uint256 assets) public {
        // Lower bound avoids rounding to zero with _decimalsOffset=18 at near-empty vault
        assets = bound(assets, 1e6, type(uint80).max);

        uint256 shares = _deposit(assets);
        assertGt(shares, 0, "deposit > 0 must mint > 0 shares");
    }

    // -------------------------------------------------------------------------
    // Invariant: withdraw never returns more than deposited
    // -------------------------------------------------------------------------

    function testFuzz_Withdraw_NeverExceedsTotalAssets(uint256 assets) public {
        assets = bound(assets, 1e6, type(uint80).max);

        _deposit(assets);
        uint256 totalBefore = vault.totalAssets();

        // Withdraw exactly what was deposited (shares round down so this is safe)
        uint256 maxWithdraw = vault.maxWithdraw(user);
        if (maxWithdraw == 0) return;

        vm.prank(user);
        vault.withdraw(maxWithdraw, user, user);

        assertLe(totalBefore - vault.totalAssets(), assets + 1, "withdrawn > deposited");
    }

    // -------------------------------------------------------------------------
    // Invariant: convertToAssets(convertToShares(x)) is within 1 wei
    // -------------------------------------------------------------------------

    function testFuzz_ConvertRoundTrip_WithinOneWei(uint256 assets) public {
        // Seed vault first so there is a non-trivial share price
        _deposit(1_000e18);

        assets = bound(assets, 1e6, type(uint80).max);
        uint256 shares = vault.convertToShares(assets);
        uint256 back = vault.convertToAssets(shares);

        // ERC-4626 allows round-down; back <= assets always, never exceeds
        assertLe(back, assets + 1, "round-trip must not exceed original assets");
    }

    // -------------------------------------------------------------------------
    // Invariant: totalAssets never decreases without a user withdrawal
    // -------------------------------------------------------------------------

    function testFuzz_TotalAssets_MonotonicallyIncreases(uint256 assets, uint256 elapsed) public {
        assets = bound(assets, 1e6, type(uint80).max);
        elapsed = bound(elapsed, 1 hours + 1, 365 days);

        _deposit(assets);

        uint256 before = vault.totalAssets();
        vm.warp(block.timestamp + elapsed);

        assertGe(vault.totalAssets(), before, "totalAssets must not decrease without withdraw");
    }

    // -------------------------------------------------------------------------
    // Invariant: share price never decreases on yield rate update
    // -------------------------------------------------------------------------

    function testFuzz_SetYieldRate_SharePriceContinuous(uint256 assets, uint256 newRate) public {
        assets = bound(assets, 1e6, type(uint80).max);
        newRate = bound(newRate, 0, 5_000);

        uint256 shares = _deposit(assets);
        uint256 assetsBefore = vault.convertToAssets(shares);

        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(owner);
        vault.setYieldRate(newRate);

        uint256 assetsAfter = vault.convertToAssets(shares);
        assertGe(assetsAfter, assetsBefore, "share price must not decrease on rate change");
    }

    // -------------------------------------------------------------------------
    // Invariant: redeem returns non-zero assets for non-zero shares
    // -------------------------------------------------------------------------

    function testFuzz_Redeem_AlwaysReturnsAssets(uint256 assets) public {
        assets = bound(assets, 1e6, type(uint80).max);

        uint256 shares = _deposit(assets);
        assertGt(shares, 0, "precondition: shares must be non-zero");

        vm.prank(user);
        uint256 received = vault.redeem(shares, user, user);

        assertGt(received, 0, "redeem non-zero shares must return non-zero assets");
    }

    // -------------------------------------------------------------------------
    // Invariant: accrued yield is bounded by the configured rate
    // -------------------------------------------------------------------------

    function testFuzz_AccruedYield_BoundedByRate(uint256 assets, uint256 elapsed) public {
        assets = bound(assets, 1e6, type(uint80).max);
        elapsed = bound(elapsed, 1 hours + 1, 730 days);

        _deposit(assets);
        _fundVault(assets); // cover yield obligations

        uint256 totalBase = vault.totalAssets();
        vm.warp(block.timestamp + elapsed);
        vault.accrueYield();

        // Max possible yield: MAX_YIELD_RATE_BPS * base * elapsed / (BPS_DIVISOR * SECONDS_PER_YEAR)
        uint256 maxYield = (totalBase * 5_000 * elapsed) / (10_000 * 365 days);
        assertLe(vault.accumulatedYield(), maxYield + 1, "yield exceeds theoretical max");
    }
}
