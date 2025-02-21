// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract MockHyperminter {
    function ownerOf(uint256 hypercertId) external returns (address) {
        return tx.origin;
    }
}
