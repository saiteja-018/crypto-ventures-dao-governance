// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ITimelock
 * @notice Interface for timelock functionality
 */
interface ITimelock {
    /**
     * @notice Queues a proposal for execution after timelock
     * @param proposalId The proposal ID
     */
    function queueProposal(uint256 proposalId) external;

    /**
     * @notice Executes a queued proposal
     * @param proposalId The proposal ID
     */
    function executeProposal(uint256 proposalId) external;

    /**
     * @notice Gets the execution time for a proposal
     * @param proposalId The proposal ID
     * @return The execution timestamp (0 if not queued)
     */
    function getExecutionTime(uint256 proposalId) external view returns (uint256);

    /**
     * @notice Gets the timelock delay for a proposal type
     * @param proposalType The proposal type index
     * @return The timelock delay in seconds
     */
    function getTimelockDelay(uint256 proposalType) external view returns (uint256);
}
