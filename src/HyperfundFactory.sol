// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./Hyperfund.sol"; // Import Hyperfund contract
import "./Hyperstaker.sol"; // Import Hyperstaker contract
import {IHypercertToken} from "./interfaces/IHypercertToken.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract HyperfundFactory is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    address hypercertMinter;
    
    // Mapping to associate (hypercert ID) with Hyperfund and Hyperstaker addresses
    mapping(uint256 => address) public hyperfunds;
    mapping(uint256 => address) public hyperstakers;

    error InvalidAddress();
    error DeploymentFailed();
    error AlreadyDeployed();
    error NotOwnerOfHypercert();

    // Event to emit when a new Hyperfund is created
    event HyperfundCreated(address indexed hyperfundAddress, address indexed manager, uint256 hypercertId);

    // Event to emit when a new Hyperstaker is created
    event HyperstakerCreated(address indexed hyperstakerAddress, address indexed manager, uint256 hypercertId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _hypercertMinter) public initializer {
        require(_hypercertMinter != address(0), InvalidAddress());
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        hypercertMinter = _hypercertMinter;

    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // Function to create a new Hyperfund
    function createHyperfund(uint256 hypercertId, address manager)
        external
        returns (address)
    {
        require(manager != address(0), InvalidAddress());
        require(hyperfunds[hypercertId] == address(0), AlreadyDeployed());
        require(msg.sender == IHypercertToken(hypercertMinter).ownerOf(hypercertId + 1), NotOwnerOfHypercert());

        address newHyperfund = address(new Hyperfund(hypercertMinter, hypercertId, manager));
        require(newHyperfund != address(0), DeploymentFailed());

        hyperfunds[hypercertId] = newHyperfund;
        emit HyperfundCreated(newHyperfund, manager, hypercertId);
        return newHyperfund;
    }

    // Function to create a new Hyperstaker
    function createHyperstaker(uint256 hypercertId, address manager)
        external
        returns (address)
    {
        require(manager != address(0), InvalidAddress());
        require(hyperstakers[hypercertId] == address(0), AlreadyDeployed());
        require(msg.sender == IHypercertToken(hypercertMinter).ownerOf(hypercertId + 1), NotOwnerOfHypercert());

        address newHyperstaker = address(new Hyperstaker(hypercertMinter, hypercertId, manager));
        require(newHyperstaker != address(0), DeploymentFailed());

        hyperstakers[hypercertId] = newHyperstaker;
        emit HyperstakerCreated(newHyperstaker, manager, hypercertId);
        return newHyperstaker;
    }
}
