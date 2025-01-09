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
    address public donor = vm.addr(2);
    uint256 public totalUnits = 100;
    uint256 public amount = 10;

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

    function test_setHypercertId() public {
        vm.prank(manager);
        hyperfund.setHypercertId(baseHypercertId + 1);
        assertEq(hyperfund.hypercertId(), baseHypercertId + 1);
    }

    function testFail_setHypercertId() public {
        vm.prank(donor);
        hyperfund.setHypercertId(baseHypercertId + 1);
    }

    function test_setAllowedToken() public {
        vm.prank(manager);
        hyperfund.setAllowedToken(address(fundingToken), true);
        assertEq(hyperfund.allowedTokens(address(fundingToken)), true);
    }

    function testFail_setAllowedToken() public {
        vm.prank(donor);
        hyperfund.setAllowedToken(address(fundingToken), true);
    }

    function test_donate_ether() public {
        vm.prank(manager);
        hyperfund.setAllowedToken(address(0), true);
        vm.deal(donor, amount);
        vm.prank(donor);
        hyperfund.donate{value: amount}(address(0), amount);
        assertEq(hypercertMinter.unitsOf(fractionHypercertId + 1), amount);
        assertEq(hypercertMinter.unitsOf(fractionHypercertId), totalUnits - amount);
        assertEq(hypercertMinter.ownerOf(fractionHypercertId + 1), donor);
        assertEq(hypercertMinter.ownerOf(fractionHypercertId), address(this));
    }

    function testFail_donate_ether_amount0() public {
        vm.prank(manager);
        hyperfund.setAllowedToken(address(0), true);
        vm.deal(donor, amount);
        vm.prank(donor);
        hyperfund.donate{value: 0}(address(0), 0);
    }

    function testFail_donate_token_amount0() public {
        vm.prank(manager);
        hyperfund.setAllowedToken(address(fundingToken), true);
        fundingToken.mint(donor, amount);
        vm.startPrank(donor);
        fundingToken.approve(address(hyperfund), amount);
        hyperfund.donate(address(fundingToken), 0);
        vm.stopPrank();
    }

    function testFail_donate_ether_not_allowlisted() public {
        vm.prank(manager);
        hyperfund.setAllowedToken(address(0), false);
        vm.deal(donor, amount);
        vm.prank(donor);
        hyperfund.donate{value: amount}(address(0), amount);
    }

    function testFail_donate_token_not_allowlisted() public {
        vm.prank(manager);
        hyperfund.setAllowedToken(address(fundingToken), false);
        fundingToken.mint(donor, amount);
        vm.startPrank(donor);
        fundingToken.approve(address(hyperfund), amount);
        hyperfund.donate(address(fundingToken), amount);
        vm.stopPrank();
    }

    function testFail_donate_token_amount_exceeds_supply() public {
        vm.prank(manager);
        hyperfund.setAllowedToken(address(fundingToken), true);
        fundingToken.mint(donor, totalUnits + 1);
        vm.startPrank(donor);
        fundingToken.approve(address(hyperfund), totalUnits + 1);
        hyperfund.donate(address(fundingToken), totalUnits + 1);
        vm.stopPrank();
    }

    function test_donate_token() public {
        vm.prank(manager);
        hyperfund.setAllowedToken(address(fundingToken), true);
        fundingToken.mint(donor, 10);

        vm.startPrank(donor);
        fundingToken.approve(address(hyperfund), amount);
        hyperfund.donate(address(fundingToken), amount);
        vm.stopPrank();
        assertEq(hypercertMinter.unitsOf(fractionHypercertId + 1), amount);
        assertEq(hypercertMinter.unitsOf(fractionHypercertId), totalUnits - amount);
        assertEq(hypercertMinter.ownerOf(fractionHypercertId + 1), donor);
        assertEq(hypercertMinter.ownerOf(fractionHypercertId), address(this));
    }

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data)
        external
        pure
        returns (bytes4)
    {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }
}
