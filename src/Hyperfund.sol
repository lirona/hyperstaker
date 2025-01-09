// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IHypercertToken} from "./interfaces/IHypercertToken.sol";

contract Hyperfund is AccessControl, Pausable {
    IHypercertToken public hypercertMinter;
    uint256 public immutable hypercertId;
    uint256 public immutable hypercertUnits;

    // erc20 token allowlist, 0 means the token is not allowed
    // negative multiplier means the total amount of hypercert units is smaller than the amount of tokens it represents and rounding is applied
    mapping(address token => int256 multiplier) public tokenMultipliers;
    // hypercert fraction token id => isClaimed
    mapping(uint256 => bool) public isClaimed;

    //Roles
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    constructor(address _hypercertMinter, uint256 _hypercertId, address _manager) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, _manager);
        hypercertId = _hypercertId;
        hypercertMinter = IHypercertToken(_hypercertMinter);
        hypercertUnits = hypercertMinter.unitsOf(_hypercertId);
    }

    /// @notice set the multiplier for a token, 0 means the token is not allowed
    /// @param _token address of the token
    /// @param _multiplier multiplier for the token, negative means the total amount of hypercert units is smaller
    /// than the amount of tokens it represents and rounding is applied
    function setTokenMultiplier(address _token, int256 _multiplier) external onlyRole(MANAGER_ROLE) {
        tokenMultipliers[_token] = _multiplier;
    }

    function withdrawDonations(address _token, uint256 _amount, address _to) external onlyRole(MANAGER_ROLE) {
        if (_token == address(0)) {
            payable(_to).transfer(_amount);
        } else {
            require(IERC20(_token).transfer(_to, _amount), "transfer failed");
        }
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice send a donation to the hyperfund and receive a hypercert fraction
    /// @param _token address of the token to donate, must be allowlisted. address(0) for native token
    /// @param _amount amount of the token to donate
    function donate(address _token, uint256 _amount) external payable whenNotPaused {
        require(tokenMultipliers[_token] != 0, "token not allowlisted");
        require(_amount != 0, "invalid amount");
        uint256 units;
        if (tokenMultipliers[_token] > 0) {
            units = _amount * uint256(tokenMultipliers[_token]);
        } else {
            units = _amount / uint256(-tokenMultipliers[_token]);
        }
        require(hypercertMinter.unitsOf(hypercertId) >= units, "amount accedes available supply");
        if (_token == address(0)) {
            require(msg.value == _amount, "invalid amount");
        } else {
            require(IERC20(_token).transferFrom(msg.sender, address(this), _amount), "transfer failed");
        }
        _mintFraction(msg.sender, units);
    }

    function _mintFraction(address account, uint256 units) internal {
        uint256[] memory newallocations = new uint256[](2);
        newallocations[0] = hypercertMinter.unitsOf(hypercertId) - units;
        newallocations[1] = units;
        address hypercertOwner = hypercertMinter.ownerOf(hypercertId);
        hypercertMinter.splitFraction(hypercertOwner, hypercertId, newallocations);
        hypercertMinter.safeTransferFrom(hypercertOwner, account, hypercertId + 1, 1, "");
    }
}
