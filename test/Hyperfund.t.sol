// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, stdError} from "forge-std/Test.sol";
import {Hyperfund} from "../src/Hyperfund.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {HypercertMinter} from "./hypercerts/HypercertMinter.sol";
import {IHypercertToken} from "./hypercerts/IHypercertToken.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract HyperfundTest is Test {
    Hyperfund public hyperfund;
    HypercertMinter public hypercertMinter;
    MockERC20 public fundingToken;
    uint256 public baseHypercertId;
    uint256 public fractionHypercertId;
    address public manager = vm.addr(1);
    address public contributor = vm.addr(2);
    uint256 public totalUnits = 100000000;
    uint256 public amount = 10000;
    bytes32 public MANAGER_ROLE = keccak256("MANAGER_ROLE");

    function setUp() public {
        manager = address(this);
        hypercertMinter = new HypercertMinter();
        baseHypercertId =
            hypercertMinter.mintClaim(address(this), totalUnits, "uri", IHypercertToken.TransferRestrictions.AllowAll);
        fractionHypercertId = baseHypercertId + 1;
        assertEq(hypercertMinter.ownerOf(fractionHypercertId), address(this));
        fundingToken = new MockERC20("Funding", "FUND");
        hyperfund = new Hyperfund(address(hypercertMinter), fractionHypercertId, manager);
        hypercertMinter.setApprovalForAll(address(hyperfund), true);
    }

    function test_Constructor() public view {
        assertEq(hyperfund.hypercertId(), fractionHypercertId);
        assertEq(address(hyperfund.hypercertMinter()), address(hypercertMinter));
    }

    function test_SetAllowedToken() public {
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit Hyperfund.TokenAllowlisted(address(fundingToken), 10);
        hyperfund.allowlistToken(address(fundingToken), 10);
        assertEq(hyperfund.tokenMultipliers(address(fundingToken)), 10);
    }

    function test_RevertWhen_setAllowedTokenNotManager() public {
        vm.prank(contributor);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, contributor, MANAGER_ROLE)
        );
        hyperfund.allowlistToken(address(fundingToken), 10);
    }

    function test_DonateEther() public {
        _testDonateEther(1);
    }

    function test_DonateEtherMultiplier500() public {
        _testDonateEther(500);
    }

    function test_DonateEtherMultiplierMinus500() public {
        _testDonateEther(-500);
    }

    function test_DonateToken() public {
        _testDonateToken(1);
    }

    function test_DonateTokenMultiplier500() public {
        _testDonateToken(500);
    }

    function test_DonateTokenMultiplierMinus500() public {
        _testDonateToken(-500);
    }

    function _testDonateEther(int256 multiplier) internal {
        vm.prank(manager);
        hyperfund.allowlistToken(address(0), multiplier);
        vm.deal(contributor, amount);
        vm.prank(contributor);
        vm.expectEmit(true, false, false, true);
        emit Hyperfund.DonationReceived(address(0), amount);
        hyperfund.donate{value: amount}(address(0), amount);
        _assertDonation(multiplier, amount);
    }

    function _testDonateToken(int256 multiplier) internal {
        vm.prank(manager);
        hyperfund.allowlistToken(address(fundingToken), multiplier);
        fundingToken.mint(contributor, amount);

        vm.startPrank(contributor);
        fundingToken.approve(address(hyperfund), amount);
        vm.expectEmit(true, false, false, true);
        emit Hyperfund.DonationReceived(address(fundingToken), amount);
        hyperfund.donate(address(fundingToken), amount);
        vm.stopPrank();
        _assertDonation(multiplier, amount);
    }

    function _assertDonation(int256 multiplier, uint256 _amount) internal view {
        uint256 units;
        if (multiplier > 0) {
            units = _amount * uint256(multiplier);
        } else {
            units = _amount / uint256(-multiplier);
        }
        _assertNewFraction(units);
    }

    function _assertNewFraction(uint256 units) internal view {
        assertEq(hypercertMinter.unitsOf(fractionHypercertId + 1), units);
        assertEq(hypercertMinter.unitsOf(fractionHypercertId), totalUnits - units);
        assertEq(hypercertMinter.ownerOf(fractionHypercertId + 1), contributor);
        assertEq(hypercertMinter.ownerOf(fractionHypercertId), address(this));
    }

    function test_RevertWhen_DonateEtherAmount0() public {
        vm.prank(manager);
        hyperfund.allowlistToken(address(0), 1);
        vm.deal(contributor, amount);
        vm.prank(contributor);
        vm.expectRevert(Hyperfund.InvalidAmount.selector);
        hyperfund.donate{value: 0}(address(0), 0);
    }

    function test_RevertWhen_DonateTokenAmount0() public {
        vm.prank(manager);
        hyperfund.allowlistToken(address(fundingToken), 1);
        fundingToken.mint(contributor, amount);
        vm.startPrank(contributor);
        fundingToken.approve(address(hyperfund), amount);
        vm.expectRevert(Hyperfund.InvalidAmount.selector);
        hyperfund.donate(address(fundingToken), 0);
        vm.stopPrank();
    }

    function test_RevertWhen_DonateEtherNotAllowlisted() public {
        vm.prank(manager);
        hyperfund.allowlistToken(address(0), 0);
        vm.deal(contributor, amount);
        vm.prank(contributor);
        vm.expectRevert(Hyperfund.TokenNotAllowlisted.selector);
        hyperfund.donate{value: amount}(address(0), amount);
    }

    function test_RevertWhen_DonateTokenNotAllowlisted() public {
        vm.prank(manager);
        hyperfund.allowlistToken(address(fundingToken), 0);
        fundingToken.mint(contributor, amount);
        vm.startPrank(contributor);
        fundingToken.approve(address(hyperfund), amount);
        vm.expectRevert(Hyperfund.TokenNotAllowlisted.selector);
        hyperfund.donate(address(fundingToken), amount);
        vm.stopPrank();
    }

    function test_RevertWhen_DonateTokenAmountExceedsSupply() public {
        vm.prank(manager);
        hyperfund.allowlistToken(address(fundingToken), 1);
        fundingToken.mint(contributor, totalUnits + 1);
        vm.startPrank(contributor);
        fundingToken.approve(address(hyperfund), totalUnits + 1);
        vm.expectRevert(abi.encodeWithSelector(Hyperfund.AmountExceedsAvailableSupply.selector, totalUnits));
        hyperfund.donate(address(fundingToken), totalUnits + 1);
        vm.stopPrank();
    }

    function test_NonfinancialContribution() public {
        vm.prank(manager);
        vm.expectEmit(true, false, false, true);
        emit Hyperfund.NonfinancialContribution(contributor, amount);
        hyperfund.nonfinancialContribution(contributor, amount);
        _assertNewFraction(amount);
    }

    function test_RevertWhen_NonfinancialContributionAmount0() public {
        vm.prank(manager);
        vm.expectRevert(Hyperfund.InvalidAmount.selector);
        hyperfund.nonfinancialContribution(contributor, 0);
    }

    function test_RevertWhen_NonfinancialContributionAmountExceedsSupply() public {
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(Hyperfund.AmountExceedsAvailableSupply.selector, totalUnits));
        hyperfund.nonfinancialContribution(contributor, totalUnits + 1);
    }

    function test_RevertWhen_NonfinancialContributionContributorIsZero() public {
        vm.prank(manager);
        vm.expectRevert(Hyperfund.InvalidAddress.selector);
        hyperfund.nonfinancialContribution(address(0), amount);
    }

    function test_RevertWhen_NonfinancialContributionNotManager() public {
        vm.prank(contributor);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, contributor, MANAGER_ROLE)
        );
        hyperfund.nonfinancialContribution(contributor, amount);
    }

    function _unitsToTokenAmount(int256 multiplier, uint256 units) internal pure returns (uint256 tokenAmount) {
        if (multiplier > 0) {
            tokenAmount = units / uint256(multiplier);
        } else {
            tokenAmount = units * uint256(-multiplier);
        }
    }

    function _testRedeem(int256 multiplier, uint256 units, address token) internal {
        vm.startPrank(manager);
        hyperfund.nonfinancialContribution(contributor, units);
        hyperfund.allowlistToken(token, multiplier);
        vm.stopPrank();
        vm.startPrank(contributor);
        hypercertMinter.setApprovalForAll(address(hyperfund), true);
        vm.expectEmit(true, false, false, true);
        emit Hyperfund.FractionRedeemed(fractionHypercertId + 1, token, _unitsToTokenAmount(multiplier, units));
        hyperfund.redeem(fractionHypercertId + 1, token);
        vm.stopPrank();
        assertEq(hypercertMinter.ownerOf(fractionHypercertId + 1), contributor);
        assertEq(hypercertMinter.unitsOf(fractionHypercertId + 1), 0);
        assertEq(hypercertMinter.unitsOf(fractionHypercertId), totalUnits - units);
    }

    function _testRedeemEther(int256 multiplier, uint256 units) internal {
        uint256 ethAmount = _unitsToTokenAmount(multiplier, units);
        vm.deal(address(hyperfund), ethAmount);
        _testRedeem(multiplier, units, address(0));
        assertEq(contributor.balance, ethAmount);
    }

    function _testRedeemToken(int256 multiplier, uint256 units) internal {
        uint256 tokenAmount = _unitsToTokenAmount(multiplier, units);
        fundingToken.mint(address(hyperfund), tokenAmount);
        _testRedeem(multiplier, units, address(fundingToken));
        assertEq(fundingToken.balanceOf(contributor), tokenAmount);
    }

    function test_RedeemEtherMultiplier1() public {
        _testRedeemEther(1, amount);
    }

    function test_RedeemEtherMultiplier500() public {
        _testRedeemEther(500, amount);
    }

    function test_RedeemEtherMultiplierMinus500() public {
        _testRedeemEther(-500, amount);
    }

    function test_RedeemTokenMultiplier1() public {
        _testRedeemToken(1, amount);
    }

    function test_RedeemTokenMultiplier500() public {
        _testRedeemToken(500, amount);
    }

    function test_RedeemTokenMultiplierMinus500() public {
        _testRedeemToken(-500, amount);
    }

    function test_RevertWhen_RedeemUserNotAllowlisted() public {
        vm.prank(manager);
        hyperfund.allowlistToken(address(fundingToken), 1);
        fundingToken.mint(contributor, amount);

        vm.startPrank(contributor);
        fundingToken.approve(address(hyperfund), amount);
        hyperfund.donate(address(fundingToken), amount);
        hypercertMinter.setApprovalForAll(address(hyperfund), true);
        vm.expectRevert(stdError.arithmeticError);
        hyperfund.redeem(fractionHypercertId + 1, address(fundingToken));
        vm.stopPrank();
    }

    function test_RevertWhen_RedeemOverAllowance() public {
        vm.startPrank(manager);
        hyperfund.allowlistToken(address(fundingToken), 1);
        hyperfund.nonfinancialContribution(contributor, amount);
        vm.stopPrank();
        fundingToken.mint(contributor, amount);
        fundingToken.mint(address(hyperfund), amount);

        vm.startPrank(contributor);
        fundingToken.approve(address(hyperfund), amount);
        hyperfund.donate(address(fundingToken), amount);
        hypercertMinter.setApprovalForAll(address(hyperfund), true);
        hyperfund.redeem(fractionHypercertId + 1, address(fundingToken));
        vm.expectRevert(stdError.arithmeticError);
        hyperfund.redeem(fractionHypercertId + 2, address(fundingToken));
        vm.stopPrank();
    }

    function test_RevertWhen_RedeemNotFraction() public {
        vm.startPrank(contributor);
        uint256 baseHypercertId1 =
            hypercertMinter.mintClaim(contributor, totalUnits, "uri", IHypercertToken.TransferRestrictions.AllowAll);
        uint256 fractionHypercertId1 = baseHypercertId1 + 1;
        vm.expectRevert(abi.encodeWithSelector(Hyperfund.NotFractionOfThisHypercert.selector, fractionHypercertId));
        hyperfund.redeem(fractionHypercertId1, address(fundingToken));
        vm.stopPrank();
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }
}
