// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IGovernanceToken
 * @notice Interface for the governance token/stake mechanism
 */
interface IGovernanceToken {
    /**
     * @notice Deposits ETH into the DAO treasury and receives governance power
     */
    function deposit() external payable;

    /**
     * @notice Withdraws staked ETH from the DAO
     * @param amount Amount of ETH to withdraw
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice Gets the voting power of a member
     * @param member The member's address
     * @return The member's voting power
     */
    function getVotingPower(address member) external view returns (uint256);

    /**
     * @notice Gets the total voting power in the DAO
     * @return The total voting power
     */
    function getTotalVotingPower() external view returns (uint256);

    /**
     * @notice Gets the stake of a member
     * @param member The member's address
     * @return The member's stake in wei
     */
    function getStake(address member) external view returns (uint256);
}
