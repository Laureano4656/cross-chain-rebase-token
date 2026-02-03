// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author Laureano
 * @notice This is a cross-chain token that incentivizes users to deposit into a vault and gain interest in rewards.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the moment of their deposit.
 */
contract RebaseToken is ERC20 {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private constant PRESICION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRates;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateUpdated(uint256 newInterestRate);

    constructor() ERC20("RebaseToken", "RBT") {}

    /**
     * @notice Set the interest rate. Can only decrease.
     * @param _newInterestRate The new interest rate to set.
     */
    function setInterestRate(uint256 _newInterestRate) external {
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateUpdated(_newInterestRate);
    }

    /**
     * @notice Mint tokens to a user when they deposit into the vault.
     * @param _to The address to mint tokens to.
     * @param _amount The amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userInterestRates[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burn tokens from a user when they withdraw from the vault.
     * @param _from The address to burn tokens from.
     * @param _amount The amount of tokens to burn.
     */
    function burn(address _from, uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = super.balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice Override balanceOf to include accrued interest.
     * @notice Calculate the balnace for the user including the interest that has accumulated since the last update. (principle balance) + some interest that has accrued
     * @param _user The user address to get the balance for.
     * @return The balance of the user including accrued interest.
     */
    function balanceOf(address _user) public view override returns (uint256) {
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRESICION_FACTOR;
    }

    /**
     * @notice Mint the accrued interest to a user since the last time they interacted with the protocol.
     * @param _user The user address to mint the interest to.
     */
    function _mintAccruedInterest(address _user) internal {
        uint256 previousPrincipleBalance = super.balanceOf(_user);

        uint256 currentBalance = balanceOf(_user);

        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;

        s_userLastUpdatedTimestamp[_user] = block.timestamp;

        _mint(_user, balanceIncrease);
    }

    /**
     * @notice Calculate the accumulated interest for a user since their last update.
     * @param _user The user address to calculate the interest for.
     * @return linearInterest The accumulated interest multiplier since the last update.
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterest)
    {
        uint256 lastUpdated = s_userLastUpdatedTimestamp[_user];
        if (lastUpdated == 0) {
            return 1e18; // No interest accrued if never updated
        }
        uint256 timeElapsed = block.timestamp - lastUpdated;
        linearInterest = PRESICION_FACTOR + (s_userInterestRates[_user] * timeElapsed);
    }

    /**
     * @notice Get the interest rate of a user.
     * @param _user The user address to get the interest rate for.
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRates[_user];
    }
}
