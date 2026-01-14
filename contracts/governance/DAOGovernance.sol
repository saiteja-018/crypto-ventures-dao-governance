// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IProposal.sol";
import "../interfaces/ITimelock.sol";
import "../interfaces/ITreasury.sol";
import "../governance/GovernanceToken.sol";
import "../governance/VotingDelegation.sol";
import "../treasury/DAOTreasury.sol";
import "../access/DAOAccessControl.sol";

/**
 * @title DAOGovernance
 * @notice Main governance contract implementing complete proposal lifecycle with timelock execution
 */
contract DAOGovernance is IProposal, ITimelock {
    // References
    GovernanceToken private _governanceToken;
    VotingDelegation private _votingDelegation;
    DAOTreasury private _treasury;
    DAOAccessControl private _accessControl;

    // Configuration
    uint256 public votingDelay;
    uint256 public votingPeriod;
    uint256 public proposalThreshold;
    uint256 public quorumPercentage;

    // Timelock delays per proposal type (in seconds)
    mapping(uint256 => uint256) private _timelockDelays;

    // State variables
    uint256 private _proposalCount;
    mapping(uint256 => Proposal) private _proposals;
    mapping(uint256 => mapping(address => bool)) private _hasVoted; // proposalId => voter => hasVoted
    mapping(uint256 => mapping(address => uint8)) private _votes; // proposalId => voter => voteType
    mapping(uint256 => uint256) private _executionTimes; // proposalId => executionTime
    mapping(uint256 => bool) private _proposalQueued; // proposalId => queued

    // Quorum requirements by proposal type
    mapping(uint256 => uint256) private _quorumRequirements;

    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address recipient,
        uint256 amount,
        string description,
        uint256 indexed proposalType
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 support,
        uint256 votingPower
    );

    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    /**
     * @notice Initializes the governance contract
     * @param governanceToken The governance token contract address
     * @param votingDelegation The voting delegation contract address
     * @param treasury The treasury contract address
     * @param accessControl The access control contract address
     */
    constructor(
        address governanceToken,
        address votingDelegation,
        address treasury,
        address accessControl
    ) {
        require(governanceToken != address(0), "Invalid governance token");
        require(votingDelegation != address(0), "Invalid voting delegation");
        require(treasury != address(0), "Invalid treasury");
        require(accessControl != address(0), "Invalid access control");

        _governanceToken = GovernanceToken(payable(governanceToken));
        _votingDelegation = VotingDelegation(payable(votingDelegation));
        _treasury = DAOTreasury(payable(treasury));
        _accessControl = DAOAccessControl(payable(accessControl));

        // Default configuration
        votingDelay = 1;
        votingPeriod = 50400; // ~1 week on Ethereum
        proposalThreshold = 1e18; // 1 ETH equivalent voting power
        quorumPercentage = 10; // 10% quorum

        // Default timelock delays (in seconds)
        _timelockDelays[0] = 2 days; // High conviction: 2 days
        _timelockDelays[1] = 1 days; // Experimental: 1 day
        _timelockDelays[2] = 6 hours; // Operational: 6 hours

        // Default quorum requirements
        _quorumRequirements[0] = 30; // High conviction: 30%
        _quorumRequirements[1] = 20; // Experimental: 20%
        _quorumRequirements[2] = 10; // Operational: 10%
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
    ) external returns (uint256 proposalId) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than 0");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(
            _governanceToken.getVotingPower(msg.sender) >= proposalThreshold,
            "Insufficient voting power to propose"
        );

        proposalId = _proposalCount++;

        uint256 startBlock = block.number + votingDelay;
        uint256 endBlock = startBlock + votingPeriod;

        _proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            recipient: recipient,
            amount: amount,
            description: description,
            proposalType: proposalType,
            startBlock: startBlock,
            endBlock: endBlock,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            cancelled: false,
            executed: false,
            eta: 0,
            queued: false
        });

        emit ProposalCreated(proposalId, msg.sender, recipient, amount, description, uint256(proposalType));

        return proposalId;
    }

    /**
     * @notice Casts a vote on a proposal
     * @param proposalId The proposal ID
     * @param support The vote type (0=Against, 1=For, 2=Abstain)
     */
    function castVote(uint256 proposalId, uint8 support) external {
        Proposal storage proposal = _proposals[proposalId];
        require(!proposal.cancelled, "Proposal is cancelled");
        require(!_hasVoted[proposalId][msg.sender], "Voter already voted");
        require(support <= 2, "Invalid vote type");

        ProposalState state = getProposalState(proposalId);
        require(state == ProposalState.Active, "Proposal is not in active state");

        uint256 votingPower = _votingDelegation.getVotingPowerWithDelegation(msg.sender);
        require(votingPower > 0, "No voting power");

        _hasVoted[proposalId][msg.sender] = true;
        _votes[proposalId][msg.sender] = support;

        if (support == 0) {
            proposal.againstVotes += votingPower;
        } else if (support == 1) {
            proposal.forVotes += votingPower;
        } else {
            proposal.abstainVotes += votingPower;
        }

        emit VoteCast(proposalId, msg.sender, support, votingPower);
    }

    /**
     * @notice Queues an approved proposal for execution
     * @param proposalId The proposal ID
     */
    function queueProposal(uint256 proposalId) external {
        Proposal storage proposal = _proposals[proposalId];
        require(!proposal.cancelled, "Proposal is cancelled");
        require(!proposal.queued, "Proposal is already queued");

        ProposalState state = getProposalState(proposalId);
        require(state == ProposalState.Defeated || block.number > proposal.endBlock, "Voting period not ended");

        // Check if proposal passed
        require(proposal.forVotes > proposal.againstVotes, "Proposal did not pass");

        // Check quorum
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 requiredQuorum = (_governanceToken.getTotalVotingPower() * _quorumRequirements[uint256(proposal.proposalType)]) / 100;
        require(totalVotes >= requiredQuorum, "Quorum not reached");

        uint256 timelockDelay = _timelockDelays[uint256(proposal.proposalType)];
        uint256 eta = block.timestamp + timelockDelay;

        proposal.eta = eta;
        proposal.queued = true;
        _executionTimes[proposalId] = eta;

        emit ProposalQueued(proposalId, eta);
    }

    /**
     * @notice Executes a queued proposal
     * @param proposalId The proposal ID
     */
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = _proposals[proposalId];
        require(!proposal.cancelled, "Proposal is cancelled");
        require(!proposal.executed, "Proposal already executed");
        require(proposal.queued, "Proposal not queued");
        require(block.timestamp >= proposal.eta, "Timelock not expired");

        proposal.executed = true;

        // Transfer funds from treasury
        ITreasury.FundCategory category;
        if (proposal.proposalType == ProposalType.HighConviction) {
            category = ITreasury.FundCategory.HighConviction;
        } else if (proposal.proposalType == ProposalType.ExperimentalBet) {
            category = ITreasury.FundCategory.ExperimentalBet;
        } else {
            category = ITreasury.FundCategory.OperationalExpense;
        }

        _treasury.transferFunds(category, proposal.recipient, proposal.amount);

        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Cancels a proposal (only by guardian)
     * @param proposalId The proposal ID
     */
    function cancelProposal(uint256 proposalId) external {
        require(
            _accessControl.hasRole(_accessControl.GUARDIAN_ROLE(), msg.sender),
            "Only guardians can cancel proposals"
        );

        Proposal storage proposal = _proposals[proposalId];
        require(!proposal.cancelled, "Proposal already cancelled");
        require(!proposal.executed, "Cannot cancel executed proposal");

        proposal.cancelled = true;

        emit ProposalCancelled(proposalId);
    }

    /**
     * @notice Gets the current state of a proposal
     * @param proposalId The proposal ID
     * @return The proposal state
     */
    function getProposalState(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = _proposals[proposalId];

        if (proposal.cancelled) {
            return ProposalState.Cancelled;
        }
        if (proposal.executed) {
            return ProposalState.Executed;
        }
        if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        }
        if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        }
        if (proposal.forVotes <= proposal.againstVotes) {
            return ProposalState.Defeated;
        }
        if (proposal.queued) {
            return ProposalState.Queued;
        }

        return ProposalState.Defeated;
    }

    /**
     * @notice Gets proposal details
     * @param proposalId The proposal ID
     * @return The proposal struct
     */
    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return _proposals[proposalId];
    }

    /**
     * @notice Gets the execution time for a proposal
     * @param proposalId The proposal ID
     * @return The execution timestamp (0 if not queued)
     */
    function getExecutionTime(uint256 proposalId) external view returns (uint256) {
        return _executionTimes[proposalId];
    }

    /**
     * @notice Gets the timelock delay for a proposal type
     * @param proposalType The proposal type index
     * @return The timelock delay in seconds
     */
    function getTimelockDelay(uint256 proposalType) external view returns (uint256) {
        return _timelockDelays[proposalType];
    }

    /**
     * @notice Sets the timelock delay for a proposal type
     * @param proposalType The proposal type index
     * @param delay The new delay in seconds
     */
    function setTimelockDelay(uint256 proposalType, uint256 delay) external {
        require(
            _accessControl.hasRole(_accessControl.TIMELOCK_ADMIN_ROLE(), msg.sender),
            "Only timelock admins can set delays"
        );
        require(proposalType < 3, "Invalid proposal type");
        _timelockDelays[proposalType] = delay;
    }

    /**
     * @notice Checks if a voter has voted on a proposal
     * @param proposalId The proposal ID
     * @param voter The voter address
     * @return True if the voter has voted
     */
    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return _hasVoted[proposalId][voter];
    }

    /**
     * @notice Gets the vote of a voter on a proposal
     * @param proposalId The proposal ID
     * @param voter The voter address
     * @return The vote type (0=Against, 1=For, 2=Abstain)
     */
    function getVote(uint256 proposalId, address voter) external view returns (uint8) {
        return _votes[proposalId][voter];
    }

    /**
     * @notice Gets the total number of proposals
     * @return The proposal count
     */
    function getProposalCount() external view returns (uint256) {
        return _proposalCount;
    }

    /**
     * @notice Sets governance parameters
     * @param _votingDelay The voting delay in blocks
     * @param _votingPeriod The voting period in blocks
     * @param _proposalThreshold The minimum voting power to propose
     * @param _quorumPercentage The quorum percentage
     */
    function setGovernanceParameters(
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumPercentage
    ) external {
        require(
            _accessControl.hasRole(_accessControl.TIMELOCK_ADMIN_ROLE(), msg.sender),
            "Only admins can set parameters"
        );

        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        proposalThreshold = _proposalThreshold;
        quorumPercentage = _quorumPercentage;
    }
}
