// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {YieldVault} from "../src/YieldVault.sol";

/// @dev Minimal ERC-20 used as the vault's underlying asset in tests.
contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract YieldVaultTest is Test {
    MockERC20 internal asset;
    YieldVault internal impl;
    YieldVault internal vault;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant INITIAL_YIELD_BPS = 500; // 5% APY
    uint256 internal constant DEPOSIT_AMOUNT = 1_000e18;

    function setUp() public {
        asset = new MockERC20("Mock USDC", "USDC");

        impl = new YieldVault();

        bytes memory initData = abi.encodeWithSelector(
            YieldVault.initialize.selector,
            address(asset),
            "Ferros Vault USDC",
            "fvUSDC",
            INITIAL_YIELD_BPS,
            owner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        vault = YieldVault(address(proxy));

        asset.mint(alice, 10_000e18);
        asset.mint(bob, 10_000e18);
        asset.mint(owner, 100_000e18);
    }

    // -------------------------------------------------------------------------
    // Initialization
    // -------------------------------------------------------------------------

    function test_Initialize_SetsYieldRate() public {
        assertEq(vault.yieldRateBps(), INITIAL_YIELD_BPS);
    }

    function test_Initialize_SetsOwner() public {
        assertEq(vault.owner(), owner);
    }

    function test_Initialize_SetsVersion() public {
        assertEq(vault.version(), "1.0.0");
    }

    function test_Initialize_SetsAsset() public {
        assertEq(vault.asset(), address(asset));
    }

    function test_Initialize_CannotReinitialize() public {
        vm.expectRevert();
        vault.initialize(IERC20(address(asset)), "X", "X", 0, owner);
    }

    // -------------------------------------------------------------------------
    // Deposit
    // -------------------------------------------------------------------------

    function test_Deposit_MintsSharesProportional() public {
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();

        assertGt(shares, 0, "shares must be > 0");
        assertEq(vault.balanceOf(alice), shares);
    }

    function test_Deposit_IncreasesTotalAssets() public {
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();

        assertGe(vault.totalAssets(), DEPOSIT_AMOUNT);
    }

    function test_Deposit_TwoDepositors_SharesSumCorrectly() public {
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 sharesA = vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 sharesB = vault.deposit(DEPOSIT_AMOUNT, bob);
        vm.stopPrank();

        assertApproxEqRel(sharesA, sharesB, 1e15, "equal deposits => equal shares");
    }

    function test_Deposit_RevertsWhenPaused() public {
        vm.prank(owner);
        vault.pause();

        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        vm.expectRevert();
        vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Withdraw
    // -------------------------------------------------------------------------

    function _depositAlice() internal returns (uint256 shares) {
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        shares = vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();
    }

    function test_Withdraw_BurnsShares() public {
        uint256 shares = _depositAlice();

        vm.prank(alice);
        vault.withdraw(DEPOSIT_AMOUNT, alice, alice);

        assertLt(vault.balanceOf(alice), shares);
    }

    function test_Withdraw_TransfersAssets() public {
        _depositAlice();
        uint256 balBefore = asset.balanceOf(alice);

        vm.prank(alice);
        vault.withdraw(DEPOSIT_AMOUNT, alice, alice);

        assertGt(asset.balanceOf(alice), balBefore);
    }

    function test_Withdraw_CannotExceedBalance() public {
        _depositAlice();

        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(DEPOSIT_AMOUNT + 1, alice, alice);
    }

    function test_Withdraw_RevertsWhenPaused() public {
        _depositAlice();

        vm.prank(owner);
        vault.pause();

        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(DEPOSIT_AMOUNT, alice, alice);
    }

    // -------------------------------------------------------------------------
    // Redeem
    // -------------------------------------------------------------------------

    function test_Redeem_ReturnsCorrectAssets() public {
        uint256 shares = _depositAlice();
        uint256 expected = vault.convertToAssets(shares);

        vm.prank(alice);
        uint256 received = vault.redeem(shares, alice, alice);

        assertApproxEqRel(received, expected, 1e15, "redeem assets off");
    }

    function test_Redeem_RevertsWhenPaused() public {
        uint256 shares = _depositAlice();

        vm.prank(owner);
        vault.pause();

        vm.prank(alice);
        vm.expectRevert();
        vault.redeem(shares, alice, alice);
    }

    // -------------------------------------------------------------------------
    // Yield accrual
    // -------------------------------------------------------------------------

    function _fundVaultYield() internal {
        vm.prank(owner);
        asset.transfer(address(vault), 10_000e18);
    }

    function test_AccrueYield_IncreasesTotalAssets() public {
        _depositAlice();
        _fundVaultYield();
        uint256 before = vault.totalAssets();

        vm.warp(block.timestamp + 1 hours + 1);
        vault.accrueYield();

        assertGt(vault.totalAssets(), before);
    }

    function test_AccrueYield_RespectMinInterval() public {
        _depositAlice();
        _fundVaultYield();

        vm.warp(block.timestamp + 1 hours + 1);
        vault.accrueYield();
        uint256 accBefore = vault.accumulatedYield();

        // Second call within min interval — must be a no-op
        vault.accrueYield();
        assertEq(vault.accumulatedYield(), accBefore, "second call must be no-op");
    }

    function test_AccrueYield_ZeroRate_NoIncrease() public {
        _depositAlice();

        vm.prank(owner);
        vault.setYieldRate(0);

        uint256 base = vault.totalAssets();
        vm.warp(block.timestamp + 365 days);
        vault.accrueYield();

        assertEq(vault.totalAssets(), base, "zero rate must not change totalAssets");
    }

    function test_AccrueYield_30Days_ApproximatelyCorrect() public {
        _depositAlice();
        _fundVaultYield();

        vm.warp(block.timestamp + 30 days);
        vault.accrueYield();

        // 5% APY over 30 days on total vault balance (deposit + funded yield reserves)
        uint256 vaultBalance = asset.balanceOf(address(vault));
        uint256 expectedInterest = (vaultBalance * 500 * 30 days) / (10_000 * 365 days);
        assertApproxEqRel(vault.accumulatedYield(), expectedInterest, 1e15);
    }

    // -------------------------------------------------------------------------
    // setYieldRate
    // -------------------------------------------------------------------------

    function test_SetYieldRate_UpdatesRate() public {
        vm.prank(owner);
        vault.setYieldRate(1_000);

        assertEq(vault.yieldRateBps(), 1_000);
    }

    function test_SetYieldRate_EmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit YieldVault.YieldRateUpdated(INITIAL_YIELD_BPS, 1_000);
        vault.setYieldRate(1_000);
    }

    function test_SetYieldRate_RevertsIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.setYieldRate(1_000);
    }

    function test_SetYieldRate_RevertsIfExceedsCeiling() public {
        vm.prank(owner);
        vm.expectRevert();
        vault.setYieldRate(5_001);
    }

    function test_SetYieldRate_ZeroDisablesYield() public {
        _depositAlice();
        uint256 base = vault.totalAssets();

        vm.prank(owner);
        vault.setYieldRate(0);

        vm.warp(block.timestamp + 365 days);
        assertEq(vault.totalAssets(), base, "rate=0 must freeze totalAssets");
    }

    // -------------------------------------------------------------------------
    // Pause / Unpause
    // -------------------------------------------------------------------------

    function test_Pause_RevertsIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.pause();
    }

    function test_Unpause_RestoresDeposit() public {
        vm.prank(owner);
        vault.pause();

        vm.prank(owner);
        vault.unpause();

        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();

        assertGt(shares, 0);
    }

    // -------------------------------------------------------------------------
    // Access control — UUPS upgrade
    // -------------------------------------------------------------------------

    function test_UpgradeAuthorization_RevertsIfNotOwner() public {
        YieldVault newImpl = new YieldVault();

        vm.prank(alice);
        vm.expectRevert();
        vault.upgradeToAndCall(address(newImpl), "");
    }

    // -------------------------------------------------------------------------
    // Ownable2Step
    // -------------------------------------------------------------------------

    function test_TransferOwnership_TwoStep() public {
        vm.prank(owner);
        vault.transferOwnership(alice);

        // Still pending — owner unchanged
        assertEq(vault.owner(), owner);

        vm.prank(alice);
        vault.acceptOwnership();

        assertEq(vault.owner(), alice);
    }

    // -------------------------------------------------------------------------
    // Share math round-trip
    // -------------------------------------------------------------------------

    function test_ConvertRoundTrip_SelfConsistent() public {
        _depositAlice();
        uint256 assets = 500e18;
        uint256 shares = vault.convertToShares(assets);
        uint256 back = vault.convertToAssets(shares);
        assertApproxEqAbs(back, assets, 1, "round-trip within 1 wei");
    }

    // -------------------------------------------------------------------------
    // fundingShortfall
    // -------------------------------------------------------------------------

    function test_FundingShortfall_ZeroWhenFullyBacked() public {
        _depositAlice();
        _fundVaultYield();

        vm.warp(block.timestamp + 1 hours + 1);
        vault.accrueYield();

        assertEq(vault.fundingShortfall(), 0);
    }
}
