// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IHypercertToken} from "./interfaces/IHypercertToken.sol";

/// @notice Storage contract for Hyperfund, used to store the immutable hypercert data
contract HyperfundStorage {
    address public immutable hypercertMinter;
    uint256 public immutable hypercertId;
    uint256 public immutable hypercertTypeId;
    uint256 public immutable hypercertUnits;

    constructor(address _hypercertMinter, uint256 _hypercertId) {
        hypercertMinter = _hypercertMinter;
        hypercertId = _hypercertId;
        uint256 typeMask = type(uint256).max << 128;
        hypercertTypeId = hypercertId & typeMask;
        hypercertUnits = IHypercertToken(_hypercertMinter).unitsOf(_hypercertId);
    }
}
