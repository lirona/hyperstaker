// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./Hyperfund.sol"; // Import Hyperfund contract
import "./Hyperstaker.sol"; // Import Hyperstaker contract

contract HyperfundFactory {
    // Mapping to associate (manager address, hypercert ID) with Hyperfund and Hyperstaker addresses
    mapping(uint256 => address) public hyperfunds;
    mapping(uint256 => address) public hyperstakers;

    // Event to emit when a new Hyperfund is created
    event HyperfundCreated(address indexed hyperfundAddress, address indexed manager, uint256 hypercertId);

    // Event to emit when a new Hyperstaker is created
    event HyperstakerCreated(address indexed hyperstakerAddress, address indexed manager, uint256 hypercertId);

    // Function to create a new Hyperfund
    function createHyperfund(address hypercertMinter, uint256 hypercertId, address manager)
        external
        returns (address)
    {
        require(hypercertMinter != address(0), "Invalid hypercert minter");
        require(manager != address(0), "Invalid manager");

        address newHyperfund = address(new Hyperfund(hypercertMinter, hypercertId, manager));
        require(newHyperfund != address(0), "Hyperfund deployment failed");

        hyperfunds[hypercertId] = newHyperfund;
        emit HyperfundCreated(address(newHyperfund), manager, hypercertId);
        return newHyperfund;
    }

    // Function to create a new Hyperstaker
    function createHyperstaker(address hypercertMinter, uint256 hypercertId, address manager)
        external
        returns (address)
    {
        require(hypercertMinter != address(0), "Invalid hypercert minter");
        require(manager != address(0), "Invalid manager");

        address newHyperstaker = address(new Hyperstaker(hypercertMinter, hypercertId, manager));
        require(newHyperstaker != address(0), "Hyperstaker deployment failed");

        hyperstakers[hypercertId] = newHyperstaker;
        emit HyperstakerCreated(newHyperstaker, manager, hypercertId);
        return newHyperstaker;
    }
}
