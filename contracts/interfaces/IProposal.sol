// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IProposal
 * @notice Interface for proposal-related functionality
 */
interface IProposal {
    enum ProposalType {
        HighConviction,
        ExperimentalBet,
        OperationalExpense
    }

    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Queued,
        Expired,
        Executed,
        Cancelled
    }

    enum VoteType {
        Against,
        For,
        Abstain
    }

    struct Proposal {
        uint256 id;
        address proposer;
        address recipient;
        uint256 amount;
        string description;
        ProposalType proposalType;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool cancelled;
        bool executed;
        uint256 eta;
        bool queued;
    }

    /**
     * @notice Creates a new proposal
     * @param recipient The recipient address for fund transfer
     * @param amount The amount to transfer
     * @param description The proposal description
     * @param proposalType The type of proposal
     * @return proposalId The ID of the created proposal
     */
    function createProposal(
        address recipient,
        uint256 amount,
        string calldata description,
        ProposalType proposalType
    ) external returns (uint256 proposalId);

    /**
     * @notice Casts a vote on a proposal
     * @param proposalId The proposal ID
     * @param support The vote type (0=Against, 1=For, 2=Abstain)
     */
    function castVote(uint256 proposalId, uint8 support) external;

    /**
     * @notice Gets the current state of a proposal
     * @param proposalId The proposal ID
     * @return The proposal state
     */
    function getProposalState(uint256 proposalId) external view returns (ProposalState);

    /**
     * @notice Gets proposal details
     * @param proposalId The proposal ID
     * @return The proposal struct
     */
    function getProposal(uint256 proposalId) external view returns (Proposal memory);
}
