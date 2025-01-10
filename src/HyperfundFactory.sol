// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./Hyperfund.sol"; // Import Hyperfund contract
import "./Hyperstaker.sol"; // Import Hyperstaker contract

contract HyperfundFactory {
    Hyperfund[] public hyperfunds; // Array to store deployed Hyperfund contracts
    Hyperstaker[] public hyperstakers; // Array to store deployed Hyperstaker contracts

    // Mapping to associate (manager address, hypercert ID) with Hyperfund and Hyperstaker addresses
    mapping(address => mapping(uint256 => Hyperfund)) public hyperfundsByManager;
    mapping(address => mapping(uint256 => Hyperstaker)) public hyperstakersByManager;

    // Event to emit when a new Hyperfund is created
    event HyperfundCreated(address indexed hyperfundAddress, address indexed manager, uint256 hypercertId);

    // Event to emit when a new Hyperstaker is created
    event HyperstakerCreated(address indexed hyperstakerAddress, address indexed manager, uint256 hypercertId);

    // Function to create a new Hyperfund
    function createHyperfund(address hypercertMinter, uint256 hypercertId, address manager) external {
        require(hypercertMinter != address(0), "Invalid hypercert minter");
        require(manager != address(0), "Invalid manager");

        Hyperfund newHyperfund = new Hyperfund(hypercertMinter, hypercertId, manager);
        require(address(newHyperfund) != address(0), "Hyperfund deployment failed");

        hyperfunds.push(newHyperfund);
        hyperfundsByManager[manager][hypercertId] = newHyperfund;
        emit HyperfundCreated(address(newHyperfund), manager, hypercertId);
    }

    // Function to create a new Hyperstaker
    function createHyperstaker(address hypercertMinter, uint256 hypercertId, address manager) external {
        require(hypercertMinter != address(0), "Invalid hypercert minter");
        require(manager != address(0), "Invalid manager");

        Hyperstaker newHyperstaker = new Hyperstaker(hypercertMinter, hypercertId, manager);
        require(address(newHyperstaker) != address(0), "Hyperstaker deployment failed");

        hyperstakers.push(newHyperstaker);
        hyperstakersByManager[manager][hypercertId] = newHyperstaker;
        emit HyperstakerCreated(address(newHyperstaker), manager, hypercertId);
    }

    // Function to get all deployed Hyperfunds
    function getHyperfunds() external view returns (Hyperfund[] memory) {
        return hyperfunds; // Return the array of Hyperfunds
    }

    // Function to get all deployed Hyperstakers
    function getHyperstakers() external view returns (Hyperstaker[] memory) {
        return hyperstakers; // Return the array of Hyperstakers
    }
}
