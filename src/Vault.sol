// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    IRebaseToken private immutable i_rebaseTokenAddress;

    error Vault__RedeemFailed(address user, uint256 amount);

    event Vault__Deposit(address indexed user, uint256 amount);
    event Vault__Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseTokenAddress) {
        i_rebaseTokenAddress = _rebaseTokenAddress;
    }

    receive() external payable {}

    /**
     * @notice Deposits Ether into the vault and mints rebase tokens to the sender.
     */
    function deposit() external payable {
        uint256 userInterestRate = i_rebaseTokenAddress.getInterestRate();
        i_rebaseTokenAddress.mint(msg.sender, msg.value, userInterestRate);
        emit Vault__Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Redeems rebase tokens for Ether from the vault.
     * @param _amount The amount of rebase tokens to redeem.
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseTokenAddress.balanceOf(msg.sender);
        }
        i_rebaseTokenAddress.burn(msg.sender, _amount);
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed(msg.sender, _amount);
        }
        emit Vault__Redeem(msg.sender, _amount);
    }

    /**
     * @notice Gets the address of the rebase token contract.
     * @return The address of the rebase token contract.
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseTokenAddress);
    }
}
