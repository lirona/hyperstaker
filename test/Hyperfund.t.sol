// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Hyperfund} from "../src/Hyperfund.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {HypercertMinter} from "./hypercerts/HypercertMinter.sol";
import {IHypercertToken} from "./hypercerts/IHypercertToken.sol";

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

    function test_setAllowedToken() public {
        vm.prank(manager);
        hyperfund.allowlistToken(address(fundingToken), 10);
        assertEq(hyperfund.tokenMultipliers(address(fundingToken)), 10);
    }

    function testFail_setAllowedToken_not_manager() public {
        vm.prank(contributor);
        hyperfund.allowlistToken(address(fundingToken), 10);
    }

    function test_donate_ether() public {
        _test_donate_ether(1);
    }

    function test_donate_ether_multiplier_500() public {
        _test_donate_ether(500);
    }

    function test_donate_ether_multiplier_minus_500() public {
        _test_donate_ether(-500);
    }

    function test_donate_token() public {
        _test_donate_token(1);
    }

    function test_donate_token_multiplier_500() public {
        _test_donate_token(500);
    }

    function test_donate_token_multiplier_minus_500() public {
        _test_donate_token(-500);
    }

    function _test_donate_ether(int256 multiplier) internal {
        vm.prank(manager);
        hyperfund.allowlistToken(address(0), multiplier);
        vm.deal(contributor, amount);
        vm.prank(contributor);
        hyperfund.donate{value: amount}(address(0), amount);
        _assertDonation(multiplier, amount);
    }

    function _test_donate_token(int256 multiplier) internal {
        vm.prank(manager);
        hyperfund.allowlistToken(address(fundingToken), multiplier);
        fundingToken.mint(contributor, amount);

        vm.startPrank(contributor);
        fundingToken.approve(address(hyperfund), amount);
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

    function testFail_donate_ether_amount0() public {
        vm.prank(manager);
        hyperfund.allowlistToken(address(0), 1);
        vm.deal(contributor, amount);
        vm.prank(contributor);
        hyperfund.donate{value: 0}(address(0), 0);
    }

    function testFail_donate_token_amount0() public {
        vm.prank(manager);
        hyperfund.allowlistToken(address(fundingToken), 1);
        fundingToken.mint(contributor, amount);
        vm.startPrank(contributor);
        fundingToken.approve(address(hyperfund), amount);
        hyperfund.donate(address(fundingToken), 0);
        vm.stopPrank();
    }

    function testFail_donate_ether_not_allowlisted() public {
        vm.prank(manager);
        hyperfund.allowlistToken(address(0), 0);
        vm.deal(contributor, amount);
        vm.prank(contributor);
        hyperfund.donate{value: amount}(address(0), amount);
    }

    function testFail_donate_token_not_allowlisted() public {
        vm.prank(manager);
        hyperfund.allowlistToken(address(fundingToken), 0);
        fundingToken.mint(contributor, amount);
        vm.startPrank(contributor);
        fundingToken.approve(address(hyperfund), amount);
        hyperfund.donate(address(fundingToken), amount);
        vm.stopPrank();
    }

    function testFail_donate_token_amount_exceeds_supply() public {
        vm.prank(manager);
        hyperfund.allowlistToken(address(fundingToken), 1);
        fundingToken.mint(contributor, totalUnits + 1);
        vm.startPrank(contributor);
        fundingToken.approve(address(hyperfund), totalUnits + 1);
        hyperfund.donate(address(fundingToken), totalUnits + 1);
        vm.stopPrank();
    }

    function test_nonfinancialContribution() public {
        vm.prank(manager);
        hyperfund.nonfinancialContribution(contributor, 10000);
        _assertNewFraction(10000);
    }

    function testFail_nonfinancialContribution_amount0() public {
        vm.prank(manager);
        hyperfund.nonfinancialContribution(contributor, 0);
    }

    function testFail_nonfinancialContribution_amount_exceeds_supply() public {
        vm.prank(manager);
        hyperfund.nonfinancialContribution(contributor, totalUnits + 1);
    }

    function testFail_nonfinancialContribution_contributor_is_zero() public {
        vm.prank(manager);
        hyperfund.nonfinancialContribution(address(0), 10000);
    }

    function testFail_nonfinancialContribution_not_manager() public {
        vm.prank(contributor);
        hyperfund.nonfinancialContribution(contributor, 10000);
    }

    function _unitsToTokenAmount(int256 multiplier, uint256 units) internal pure returns (uint256 tokenAmount) {
        if (multiplier > 0) {
            tokenAmount = units / uint256(multiplier);
        } else {
            tokenAmount = units * uint256(-multiplier);
        }
    }

    function _test_redeem(int256 multiplier, uint256 units, address token) internal {
        vm.startPrank(manager);
        hyperfund.nonfinancialContribution(contributor, units);
        hyperfund.allowlistToken(token, multiplier);
        vm.stopPrank();
        vm.startPrank(contributor);
        hypercertMinter.setApprovalForAll(address(hyperfund), true);
        hyperfund.redeem(fractionHypercertId + 1, token);
        vm.stopPrank();
        assertEq(hypercertMinter.ownerOf(fractionHypercertId + 1), contributor);
        assertEq(hypercertMinter.unitsOf(fractionHypercertId + 1), 0);
        assertEq(hypercertMinter.unitsOf(fractionHypercertId), totalUnits - units);
    }

    function _test_redeem_ether(int256 multiplier, uint256 units) internal {
        uint256 ethAmount = _unitsToTokenAmount(multiplier, units);
        vm.deal(address(hyperfund), ethAmount);
        _test_redeem(multiplier, units, address(0));
        assertEq(contributor.balance, ethAmount);
    }

    function _test_redeem_token(int256 multiplier, uint256 units) internal {
        uint256 tokenAmount = _unitsToTokenAmount(multiplier, units);
        fundingToken.mint(address(hyperfund), tokenAmount);
        _test_redeem(multiplier, units, address(fundingToken));
        assertEq(fundingToken.balanceOf(contributor), tokenAmount);
    }

    function test_redeem_ether_multiplier_1() public {
        _test_redeem_ether(1, 10000);
    }

    function test_redeem_ether_multiplier_500() public {
        _test_redeem_ether(500, 10000);
    }

    function test_redeem_ether_multiplier_minus_500() public {
        _test_redeem_ether(-500, 10000);
    }

    function test_redeem_token_multiplier_1() public {
        _test_redeem_token(1, 10000);
    }

    function test_redeem_token_multiplier_500() public {
        _test_redeem_token(500, 10000);
    }

    function test_redeem_token_multiplier_minus_500() public {
        _test_redeem_token(-500, 10000);
    }

    function testFail_redeem_not_allowlisted() public {
        vm.prank(manager);
        hyperfund.allowlistToken(address(fundingToken), 1);
        fundingToken.mint(contributor, amount);

        vm.startPrank(contributor);
        fundingToken.approve(address(hyperfund), amount);
        hyperfund.donate(address(fundingToken), amount);
        hyperfund.redeem(fractionHypercertId + 1, address(fundingToken));
        vm.stopPrank();
    }

    function testFail_redeem_over_allowance() public {
        vm.startPrank(manager);
        hyperfund.allowlistToken(address(fundingToken), 1);
        hyperfund.nonfinancialContribution(contributor, 10000);
        vm.stopPrank();
        fundingToken.mint(contributor, amount);

        vm.startPrank(contributor);
        fundingToken.approve(address(hyperfund), amount);
        hyperfund.donate(address(fundingToken), amount);
        hyperfund.redeem(fractionHypercertId + 1, address(fundingToken));
        hyperfund.redeem(fractionHypercertId + 2, address(fundingToken));
        vm.stopPrank();
    }

    function testFail_redeem_not_fraction() public {
        uint256 baseHypercertId1 =
            hypercertMinter.mintClaim(contributor, totalUnits, "uri", IHypercertToken.TransferRestrictions.AllowAll);
        uint256 fractionHypercertId1 = baseHypercertId1 + 1;
        vm.prank(contributor);
        hyperfund.redeem(fractionHypercertId1, address(fundingToken));
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }
}
