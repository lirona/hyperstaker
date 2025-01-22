// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IHypercertToken} from "./interfaces/IHypercertToken.sol";

contract Hyperfund is AccessControl, Pausable {
    IHypercertToken public hypercertMinter;
    uint256 public immutable hypercertId;
    uint256 public immutable hypercertTypeId;
    uint256 public immutable hypercertUnits;

    uint256 internal fractionCounter = 1;

    uint256 internal constant TYPE_MASK = type(uint256).max << 128;

    // erc20 token allowlist, 0 means the token is not allowed
    // negative multiplier means the total amount of hypercert units is smaller than the amount of tokens it represents and rounding is applied
    mapping(address token => int256 multiplier) public tokenMultipliers;

    // allowlist for non-financial contributions, 0 means the contributor is not allowed
    mapping(address contributor => uint256 units) public nonfinancialContributions;

    //Roles
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    error TokenNotAllowlisted();
    error InvalidAmount();
    error InvalidAddress();
    error AmountExceedsAvailableSupply(uint256 availableSupply);
    error TransferFailed();
    error NotFractionOfThisHypercert(uint256 rightHypercertId);
    error Unauthorized();

    constructor(address _hypercertMinter, uint256 _hypercertId, address _manager) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, _manager);
        hypercertId = _hypercertId;
        hypercertTypeId = hypercertId & TYPE_MASK;
        hypercertMinter = IHypercertToken(_hypercertMinter);
        hypercertUnits = hypercertMinter.unitsOf(_hypercertId);
    }

    /// @notice set the multiplier for an allowlisted token, 0 means the token is not allowed
    /// @param _token address of the token
    /// @param _multiplier multiplier for the token, negative means the total amount of hypercert units is smaller
    /// than the amount of tokens it represents and rounding is applied
    function allowlistToken(address _token, int256 _multiplier) external onlyRole(MANAGER_ROLE) {
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
        require(tokenMultipliers[_token] != 0, TokenNotAllowlisted());
        require(_amount != 0, InvalidAmount());
        uint256 units = _tokenAmountToUnits(_token, _amount);
        uint256 availableSupply = hypercertMinter.unitsOf(hypercertId);
        require(availableSupply >= units, AmountExceedsAvailableSupply(availableSupply));
        if (_token == address(0)) {
            require(msg.value == _amount, InvalidAmount());
        } else {
            require(IERC20(_token).transferFrom(msg.sender, address(this), _amount), TransferFailed());
        }
        _mintFraction(msg.sender, units);
    }

    function nonfinancialContribution(address _contributor, uint256 _units)
        external
        whenNotPaused
        onlyRole(MANAGER_ROLE)
    {
        require(_contributor != address(0), InvalidAddress());
        require(_units != 0, InvalidAmount());
        uint256 availableSupply = hypercertMinter.unitsOf(hypercertId);
        require(availableSupply >= _units, AmountExceedsAvailableSupply(availableSupply));
        nonfinancialContributions[_contributor] += _units;
        _mintFraction(_contributor, _units);
    }

    /// @notice redeem a hypercert fraction for the corresponding amount of tokens
    /// NOTE: sender must first approve the hyperfund to burn the hypercert fraction, by calling hypercertMinter.setApprovalForAll(address(this), true)
    /// @param _fractionId id of the hypercert fraction
    /// @param _token address of the token to redeem, must be allowlisted. address(0) for native token
    function redeem(uint256 _fractionId, address _token) external whenNotPaused {
        require(hypercertMinter.ownerOf(_fractionId) == msg.sender, Unauthorized());
        require(_isFraction(_fractionId), NotFractionOfThisHypercert(hypercertId));
        uint256 units = hypercertMinter.unitsOf(_fractionId);
        uint256 tokenAmount = _unitsToTokenAmount(_token, units);
        if (_token == address(0)) {
            (bool success,) = payable(msg.sender).call{value: tokenAmount}("");
            require(success, TransferFailed());
        } else {
            require(IERC20(_token).transfer(msg.sender, tokenAmount), TransferFailed());
        }
        hypercertMinter.burnFraction(msg.sender, _fractionId); // sets the units of the fraction to 0
        nonfinancialContributions[msg.sender] -= units; // will underflow if the sender is not allowlisted
    }

    function _mintFraction(address account, uint256 units) internal {
        uint256[] memory newallocations = new uint256[](2);
        newallocations[0] = hypercertMinter.unitsOf(hypercertId) - units;
        newallocations[1] = units;
        address hypercertOwner = hypercertMinter.ownerOf(hypercertId);
        hypercertMinter.splitFraction(hypercertOwner, hypercertId, newallocations);
        hypercertMinter.safeTransferFrom(hypercertOwner, account, hypercertId + fractionCounter, 1, "");
        fractionCounter++;
    }

    function _tokenAmountToUnits(address _token, uint256 _amount) internal view returns (uint256 units) {
        int256 multiplier = tokenMultipliers[_token];
        if (multiplier > 0) {
            units = _amount * uint256(multiplier);
        } else {
            units = _amount / uint256(-multiplier);
        }
    }

    function _unitsToTokenAmount(address _token, uint256 _units) internal view returns (uint256 amount) {
        int256 multiplier = tokenMultipliers[_token];
        if (multiplier > 0) {
            amount = _units / uint256(multiplier);
        } else {
            amount = _units * uint256(-multiplier);
        }
    }

    function _isFraction(uint256 _fractionId) internal view returns (bool) {
        return _fractionId & TYPE_MASK == hypercertTypeId;
    }
}
