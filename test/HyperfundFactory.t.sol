// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import "../src/HyperfundFactory.sol";
import "../src/Hyperfund.sol";
import "../src/Hyperstaker.sol";
import {HypercertMinter} from "./hypercerts/HypercertMinter.sol";
import {IHypercertToken as HT} from "./hypercerts/IHypercertToken.sol";

contract HyperfundFactoryTest is Test {
    HyperfundFactory hyperfundFactory;
    Hyperfund hyperfund;
    Hyperstaker hyperstaker;

    HypercertMinter public hypercertMinter;
    uint256 hypercertId;
    address manager;
    uint256 public totalUnits = 100000000;

    function setUp() public {
        hyperfundFactory = new HyperfundFactory();
        manager = address(this);
        hypercertMinter = new HypercertMinter();
        hypercertId = hypercertMinter.mintClaim(address(this), totalUnits, "uri", HT.TransferRestrictions.AllowAll);
    }

    function testCreateHyperfund() public {
        hyperfundFactory.createHyperfund(address(hypercertMinter), hypercertId, manager);

        address createdHyperfund = hyperfundFactory.hyperfunds(hypercertId);
        assertTrue(createdHyperfund != address(0), "Hyperfund should be created and mapped correctly");
    }

    function testCreateHyperstaker() public {
        hyperfundFactory.createHyperstaker(address(hypercertMinter), hypercertId, manager);

        address createdHyperstaker = hyperfundFactory.hyperstakers(hypercertId);
        assertTrue(address(createdHyperstaker) != address(0), "Hyperstaker should be created and mapped correctly");
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }
}
