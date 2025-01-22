// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./Hyperfund.sol"; // Import Hyperfund contract
import "./Hyperstaker.sol"; // Import Hyperstaker contract
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract HyperfundFactory is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    // Mapping to associate (hypercert ID) with Hyperfund and Hyperstaker addresses
    mapping(uint256 => address) public hyperfunds;
    mapping(uint256 => address) public hyperstakers;

    error InvalidHypercertMinter();
    error InvalidManager();
    error DeploymentFailed();

    // Event to emit when a new Hyperfund is created
    event HyperfundCreated(address indexed hyperfundAddress, address indexed manager, uint256 hypercertId);

    // Event to emit when a new Hyperstaker is created
    event HyperstakerCreated(address indexed hyperstakerAddress, address indexed manager, uint256 hypercertId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // Function to create a new Hyperfund
    function createHyperfund(address hypercertMinter, uint256 hypercertId, address manager)
        external
        returns (address)
    {
        require(hypercertMinter != address(0), InvalidHypercertMinter());
        require(manager != address(0), InvalidManager());
        if (hyperfunds[hypercertId] != address(0)) {
            return hyperfunds[hypercertId];
        }

        address newHyperfund = address(new Hyperfund(hypercertMinter, hypercertId, manager));
        require(newHyperfund != address(0), DeploymentFailed());

        hyperfunds[hypercertId] = newHyperfund;
        emit HyperfundCreated(newHyperfund, manager, hypercertId);
        return newHyperfund;
    }

    // Function to create a new Hyperstaker
    function createHyperstaker(address hypercertMinter, uint256 hypercertId, address manager)
        external
        returns (address)
    {
        require(hypercertMinter != address(0), InvalidHypercertMinter());
        require(manager != address(0), InvalidManager());
        if (hyperstakers[hypercertId] != address(0)) {
            return hyperstakers[hypercertId];
        }

        address newHyperstaker = address(new Hyperstaker(hypercertMinter, hypercertId, manager));
        require(newHyperstaker != address(0), DeploymentFailed());

        hyperstakers[hypercertId] = newHyperstaker;
        emit HyperstakerCreated(newHyperstaker, manager, hypercertId);
        return newHyperstaker;
    }
}
