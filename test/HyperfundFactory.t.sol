// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import "../src/HyperfundFactory.sol";
import "../src/Hyperfund.sol";
import "../src/Hyperstaker.sol";
import {HypercertMinter} from "./hypercerts/HypercertMinter.sol";
import {IHypercertToken as HT} from "./hypercerts/IHypercertToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockHyperfundFactoryV2} from "./mocks/MockHyperfundFactoryV2.sol";

contract HyperfundFactoryTest is Test {
    HyperfundFactory implementation;
    HyperfundFactory hyperfundFactory;
    Hyperfund hyperfund;
    Hyperstaker hyperstaker;

    address public hypercertMinter;
    uint256 hypercertId;
    address manager;
    uint256 public totalUnits = 100000000;

    event Upgraded(address indexed implementation);

    function setUp() public {
        // Deploy implementation
        implementation = new HyperfundFactory();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(HyperfundFactory.initialize.selector);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        // Get factory instance
        hyperfundFactory = HyperfundFactory(address(proxy));

        manager = address(this);
        hypercertMinter = address(new HypercertMinter());
        hypercertId = HypercertMinter(hypercertMinter).mintClaim(
            address(this), totalUnits, "uri", HT.TransferRestrictions.AllowAll
        );
    }

    function test_InitialOwnership() public view {
        assertEq(hyperfundFactory.owner(), address(this));
    }

    function test_CannotInitializeTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        hyperfundFactory.initialize();
    }

    function test_CannotUpgradeFromNonOwner() public {
        MockHyperfundFactoryV2 newImplementation = new MockHyperfundFactoryV2();

        address user = makeAddr("user");
        vm.prank(user);

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        hyperfundFactory.upgradeToAndCall(address(newImplementation), "");
    }

    function test_SuccessfulUpgrade() public {
        MockHyperfundFactoryV2 newImplementation = new MockHyperfundFactoryV2();

        vm.expectEmit(true, false, false, false);
        emit Upgraded(address(newImplementation));

        hyperfundFactory.upgradeToAndCall(address(newImplementation), "");

        // Cast to V2 to test new functionality
        MockHyperfundFactoryV2 upgradedFactory = MockHyperfundFactoryV2(address(hyperfundFactory));
        assertEq(upgradedFactory.version(), 2);
    }

    function test_CreateHyperfund() public {
        hyperfundFactory.createHyperfund(hypercertMinter, hypercertId, manager);

        address createdHyperfund = hyperfundFactory.hyperfunds(hypercertId);
        assertTrue(createdHyperfund != address(0), "Hyperfund should be created and mapped correctly");
    }

    function test_CreateHyperstaker() public {
        hyperfundFactory.createHyperstaker(hypercertMinter, hypercertId, manager);

        address createdHyperstaker = hyperfundFactory.hyperstakers(hypercertId);
        assertTrue(createdHyperstaker != address(0), "Hyperstaker should be created and mapped correctly");
    }

    function test_ReturnDeployedHyperfundWhen_RedeployingHyperfundWithSameHypercertId() public {
        address createdHyperfund = hyperfundFactory.createHyperfund(hypercertMinter, hypercertId, manager);

        address returnedHyperfundAddress = hyperfundFactory.createHyperfund(hypercertMinter, hypercertId, manager);
        assertTrue(createdHyperfund == returnedHyperfundAddress, "Should not redeploy hyperfund if one already exists");
    }

    function test_ReturnDeployedHyperStakerWhen_RedeployingHyperStakerWithSameHypercertId() public {
        address createdHyperstaker = hyperfundFactory.createHyperstaker(hypercertMinter, hypercertId, manager);

        address returnedHyperstakerAddress = hyperfundFactory.createHyperstaker(hypercertMinter, hypercertId, manager);
        assertTrue(
            createdHyperstaker == returnedHyperstakerAddress, "Should not redeploy hyperstaker if one already exists"
        );
    }

    function test_RevertWhen_CreateHyperfundZeroMinter() public {
        vm.expectRevert(HyperfundFactory.InvalidHypercertMinter.selector);
        hyperfundFactory.createHyperfund(address(0), hypercertId, manager);
    }

    function test_RevertWhen_CreateHyperfundZeroManager() public {
        vm.expectRevert(HyperfundFactory.InvalidManager.selector);
        hyperfundFactory.createHyperfund(hypercertMinter, hypercertId, address(0));
    }

    function test_RevertWhen_CreateHyperstakerZeroMinter() public {
        vm.expectRevert(HyperfundFactory.InvalidHypercertMinter.selector);
        hyperfundFactory.createHyperstaker(address(0), hypercertId, manager);
    }

    function test_RevertWhen_CreateHyperstakerZeroManager() public {
        vm.expectRevert(HyperfundFactory.InvalidManager.selector);
        hyperfundFactory.createHyperstaker(hypercertMinter, hypercertId, address(0));
    }

    function test_RevertWhen_FailedHyperfundDeployment() public {
        vm.expectRevert();
        hyperfundFactory.createHyperfund(address(0x0000000000000000000000000001), hypercertId, manager);
    }

    function test_RevertWhen_FailedHyperstakerDeployment() public {
        vm.expectRevert();
        hyperfundFactory.createHyperstaker(address(0x0000000000000000000000000001), hypercertId, manager);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }
}
