// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IDelegation
 * @notice Interface for voting delegation
 */
interface IDelegation {
    /**
     * @notice Delegates voting power to another address
     * @param delegatee The address to delegate voting power to
     */
    function delegate(address delegatee) external;

    /**
     * @notice Revokes delegation
     */
    function revokeDelegation() external;

    /**
     * @notice Gets the delegate of a member
     * @param delegator The delegator address
     * @return The delegatee address (zero address if no delegation)
     */
    function getDelegation(address delegator) external view returns (address);

    /**
     * @notice Gets the voting power including delegations
     * @param account The account address
     * @return The total voting power
     */
    function getVotingPowerWithDelegation(address account) external view returns (uint256);
}
