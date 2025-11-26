// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {YieldVault} from "../src/YieldVault.sol";
import {MockYieldSource} from "../src/strategies/MockYieldSource.sol";

/// @dev Mintable ERC-20 used as testnet underlying asset.
contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract YieldVaultTest is Test {
    MockERC20 internal asset;
    MockYieldSource internal yieldSource;
    YieldVault internal vault;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal treasury = makeAddr("treasury");

    uint256 internal constant APY_BPS = 1_000;        // 10% APY
    uint256 internal constant PERF_FEE_BPS = 1_000;   // 10% performance fee
    uint256 internal constant DEPOSIT_AMOUNT = 1_000e18;

    function setUp() public {
        asset = new MockERC20("Test USDC", "tUSDC");
        yieldSource = new MockYieldSource(address(asset), APY_BPS, owner);

        YieldVault impl = new YieldVault();
        bytes memory initData = abi.encodeWithSelector(
            YieldVault.initialize.selector,
            address(asset),
            "Ferros Vault tUSDC",
            "fvUSDC",
            address(yieldSource),
            treasury,
            PERF_FEE_BPS,
            owner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        vault = YieldVault(address(proxy));

        // Wire vault address into strategy after proxy deployment (CRIT-01 fix).
        vm.prank(owner);
        yieldSource.setVault(address(vault));

        asset.mint(alice, 10_000e18);
        asset.mint(bob, 10_000e18);
    }

    // -------------------------------------------------------------------------
    // Initialization
    // -------------------------------------------------------------------------

    function test_Initialize_SetsStrategy() public {
        assertEq(address(vault.strategy()), address(yieldSource));
    }

    function test_Initialize_SetsFeeRecipient() public {
        assertEq(vault.feeRecipient(), treasury);
    }

    function test_Initialize_SetsPerformanceFee() public {
        assertEq(vault.performanceFeeBps(), PERF_FEE_BPS);
    }

    function test_Initialize_SetsOwner() public {
        assertEq(vault.owner(), owner);
    }

    function test_Initialize_SetsVersion() public {
        assertEq(vault.version(), "1.0.0");
    }

    function test_Initialize_CannotReinitialize() public {
        vm.expectRevert();
        vault.initialize(
            IERC20(address(asset)), "X", "X",
            address(yieldSource), treasury, PERF_FEE_BPS, owner
        );
    }

    // -------------------------------------------------------------------------
    // Deposit
    // -------------------------------------------------------------------------

    function test_Deposit_MintsShares() public {
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();

        assertGt(shares, 0);
        assertEq(vault.balanceOf(alice), shares);
    }

    function test_Deposit_ForwardsAssetsToStrategy() public {
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();

        assertEq(asset.balanceOf(address(yieldSource)), DEPOSIT_AMOUNT);
    }

    function test_Deposit_IncreasesTotalAssets() public {
        vm.startPrank(alice);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();

        assertGe(vault.totalAssets(), DEPOSIT_AMOUNT);
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
        uint256 maxWithdraw = vault.maxWithdraw(alice);

        vm.prank(alice);
        vault.withdraw(maxWithdraw, alice, alice);

        assertLt(vault.balanceOf(alice), shares);
    }

    function test_Withdraw_TransfersAssetsToUser() public {
        _depositAlice();
        uint256 balBefore = asset.balanceOf(alice);
        uint256 maxWithdraw = vault.maxWithdraw(alice);

        vm.prank(alice);
        vault.withdraw(maxWithdraw, alice, alice);

        assertGt(asset.balanceOf(alice), balBefore);
    }

    function test_Withdraw_CannotExceedBalance() public {
        _depositAlice();

        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(DEPOSIT_AMOUNT + 1e18, alice, alice);
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

    function test_Redeem_ReturnsAssets() public {
        uint256 shares = _depositAlice();
        uint256 expected = vault.convertToAssets(shares);

        vm.prank(alice);
        uint256 received = vault.redeem(shares, alice, alice);

        assertApproxEqRel(received, expected, 1e15);
    }

    // -------------------------------------------------------------------------
    // Yield + harvest
    // -------------------------------------------------------------------------

    function test_Harvest_MintsFeeShares() public {
        _depositAlice();

        vm.warp(block.timestamp + 30 days);
        yieldSource.accrueYield();
        vm.prank(owner);
        vault.harvest();

        assertGt(vault.balanceOf(treasury), 0, "treasury must receive fee shares");
    }

    function test_Harvest_TotalAssetsGrowsWithYield() public {
        _depositAlice();
        uint256 before = vault.totalAssets();

        vm.warp(block.timestamp + 30 days);
        yieldSource.accrueYield();

        assertGt(vault.totalAssets(), before);
    }

    function test_Harvest_FeeProportionalToGain() public {
        _depositAlice();

        vm.warp(block.timestamp + 365 days);
        yieldSource.accrueYield();

        uint256 gainBefore = vault.totalAssets() - vault.lastHarvestAssets();
        uint256 expectedFeeAssets = (gainBefore * PERF_FEE_BPS) / 10_000;

        vm.prank(owner);
        vault.harvest();

        uint256 feeShares = vault.balanceOf(treasury);
        uint256 feeAssets = vault.convertToAssets(feeShares);
        assertApproxEqRel(feeAssets, expectedFeeAssets, 2e16);
    }

    function test_Harvest_NoFeeWhenNoGain() public {
        _depositAlice();
        vm.prank(owner);
        vault.harvest();

        assertEq(vault.balanceOf(treasury), 0, "no gain = no fee");
    }

    // -------------------------------------------------------------------------
    // Performance fee config
    // -------------------------------------------------------------------------

    function test_SetPerformanceFee_UpdatesRate() public {
        vm.prank(owner);
        vault.setPerformanceFeeBps(500);
        assertEq(vault.performanceFeeBps(), 500);
    }

    function test_SetPerformanceFee_RevertsIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.setPerformanceFeeBps(500);
    }

    function test_SetPerformanceFee_RevertsIfExceedsCeiling() public {
        vm.prank(owner);
        vm.expectRevert();
        vault.setPerformanceFeeBps(3_001);
    }

    // -------------------------------------------------------------------------
    // Fee recipient
    // -------------------------------------------------------------------------

    function test_SetFeeRecipient_Updates() public {
        vm.prank(owner);
        vault.setFeeRecipient(alice);
        assertEq(vault.feeRecipient(), alice);
    }

    function test_SetFeeRecipient_RevertsIfZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert();
        vault.setFeeRecipient(address(0));
    }

    // -------------------------------------------------------------------------
    // Pause / unpause
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
    // UUPS + Ownable2Step
    // -------------------------------------------------------------------------

    function test_UpgradeAuthorization_RevertsIfNotOwner() public {
        YieldVault newImpl = new YieldVault();
        vm.prank(alice);
        vm.expectRevert();
        vault.upgradeToAndCall(address(newImpl), "");
    }

    function test_TransferOwnership_TwoStep() public {
        vm.prank(owner);
        vault.transferOwnership(alice);
        assertEq(vault.owner(), owner);

        vm.prank(alice);
        vault.acceptOwnership();
        assertEq(vault.owner(), alice);
    }

    // -------------------------------------------------------------------------
    // Share math round-trip
    // -------------------------------------------------------------------------

    function test_ConvertRoundTrip_WithinOneWei() public {
        _depositAlice();
        uint256 assets = 500e18;
        uint256 shares = vault.convertToShares(assets);
        uint256 back = vault.convertToAssets(shares);
        assertApproxEqAbs(back, assets, 1);
    }
}
