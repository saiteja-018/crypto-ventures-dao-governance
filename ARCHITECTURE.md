# CryptoVentures DAO - Architecture Documentation

## System Overview

CryptoVentures DAO is a decentralized investment governance system that implements institutional-grade governance patterns. The system manages treasury allocations and investment decisions through collective voting with advanced safeguards against attacks, manipulation, and operational failures.

## Core Design Principles

### 1. Separation of Powers
The system divides authority across multiple roles:
- **Governance Token**: Controls voting power based on stake
- **Voting Delegation**: Enables proxy voting without power transfer
- **Proposal Lifecycle**: Manages state transitions with clear checks
- **Treasury Management**: Enforces fund safety and allocation limits
- **Access Control**: Restricts sensitive operations to authorized roles

### 2. Progressive Decentralization
- Initial deployment with admin controls
- Gradually transfer governance to stakeholders
- Multi-sig controls for critical parameters
- Emergency circuit breakers for safety

### 3. Economic Incentives
- Quadratic voting aligns with optimal voting theory
- Timelock periods proportional to proposal risk
- Treasury limits prevent catastrophic failures
- Delegation incentivizes active participation

### 4. Operational Efficiency
- Fast-track for operational expenses (6 hours)
- Standard path for experiments (1 day)
- Thorough review for major investments (2 days)
- Automatic state management prevents manual errors

## Component Architecture

### 1. GovernanceToken.sol

**Purpose**: Manages member stakes and voting power calculation

**Key Functions**:
```solidity
deposit() → Adds stake, receives voting power
withdraw(amount) → Removes stake and voting power
getVotingPower(member) → Returns √(stake) for quadratic voting
getTotalVotingPower() → Sum of all members' voting power
```

**State Machine**:
```
Deposit (funds in) → Voting Power (active) → Withdrawal (funds out)
```

**Voting Power Formula**:
```
VotingPower = sqrt(StakeInWei) × PrecisionFactor
```

**Security Mechanisms**:
- Input validation for zero amounts
- Withdrawal prevented if insufficient stake
- Precise arithmetic with precision factors
- Efficient sqrt using Newton's method

**Gas Optimization**:
- Direct balance mapping (O(1) lookup)
- Sqrt calculation cached in voting records
- No external calls in core functions

### 2. VotingDelegation.sol

**Purpose**: Enables voting proxy voting without surrendering stake

**Key Functions**:
```solidity
delegate(delegatee) → Create or update delegation
revokeDelegation() → Remove delegation, reclaim voting power
getDelegation(delegator) → Get delegatee address
getVotingPowerWithDelegation(account) → Own power + delegated power
```

**Delegation Flow**:
```
Member A → delegates to → Member B
           (stake stays with A)
           (voting power flows to B)

When B votes, B's votes include A's voting power
```

**Edge Cases Handled**:
- Prevent self-delegation
- Automatic removal from old delegator list when changing targets
- Support multiple delegators to one delegate
- Revocation removes delegator from tracking array

**Complexity Analysis**:
- Delegation: O(n) worst case (array append)
- Revocation: O(n) for delegators array removal
- Voting power calculation: O(n) sum delegations
- Typical case: O(1) with small delegator counts

### 3. DAOTreasury.sol

**Purpose**: Manages multi-category fund allocation with safety limits

**Fund Categories**:
```
HighConviction (100 ETH limit)
  ↓ For major strategic investments
  ↓ Requires highest approval threshold
  
ExperimentalBet (50 ETH limit)
  ↓ For exploring new protocols
  ↓ Moderate risk tolerance
  
OperationalExpense (10 ETH limit)
  ↓ For DAO operations and tooling
  ↓ Fast approval track
```

**Key Functions**:
```solidity
depositToCategory(category) → Add funds to specific category
transferFunds(category, recipient, amount) → Withdraw from treasury
getBalance(category) → Get category balance
getTotalBalance() → Sum all categories
setBalanceLimit(category, newLimit) → Update safety limit
```

**Safety Features**:
- Category limits prevent overspending any fund type
- All transfers require governance approval
- Graceful failure when insufficient funds
- Independent category tracking

**Authorization Model**:
- Only governance contract can call transferFunds()
- Category deposits need no permission (permissionless funding)
- Balance limit changes restricted to owner

### 4. DAOAccessControl.sol

**Purpose**: Implements role-based access control for governance

**Role Definitions**:
```solidity
PROPOSER_ROLE → Can create new proposals
VOTER_ROLE → Can cast votes (all stake holders)
EXECUTOR_ROLE → Can execute approved proposals  
GUARDIAN_ROLE → Can cancel malicious proposals
TIMELOCK_ADMIN_ROLE → Can configure parameters
```

**Key Functions**:
```solidity
grantRole(role, account) → Add account to role
revokeRole(role, account) → Remove account from role
hasRole(role, account) → Check role membership
```

**Access Pattern**:
```
Owner → Can grant/revoke all roles

Member → Becomes Voter automatically (stake holder)
         Can become Proposer (if voting power ≥ threshold)
         
Governance → Can become Executor (transfer treasury funds)

Guardian → Can be multi-sig wallet (emergency override)

Admin → Controls parameter changes (voting period, thresholds, etc)
```

### 5. DAOGovernance.sol

**Purpose**: Main governance engine implementing complete proposal lifecycle

**Proposal Lifecycle**:
```
1. PENDING
   - Block number <= startBlock
   - Voting not yet active
   
2. ACTIVE
   - startBlock < block number <= endBlock
   - Members can cast votes
   - Vote weight = voting power at this block
   
3. DEFEATED
   - Block number > endBlock
   - forVotes <= againstVotes
   - OR quorum not reached
   
4. QUEUED
   - Proposal passed voting
   - Awaiting timelock expiration
   - Can be cancelled if security issue
   
5. EXECUTED
   - Timelock expired
   - Funds transferred to recipient
   - Proposal state locked
   
6. CANCELLED
   - Guardian emergency action
   - Prevents execution
   - Can be done at any time before execution
```

**Key Functions**:
```solidity
createProposal(recipient, amount, description, type)
  → Creates new proposal, returns proposalId
  
castVote(proposalId, support)
  → Votes For(1), Against(0), or Abstain(2)
  → Includes delegated voting power
  
queueProposal(proposalId)
  → Approves and queues for execution
  → Checks: passed voting, met quorum
  
executeProposal(proposalId)
  → Executes after timelock
  → Transfers funds to recipient
  
cancelProposal(proposalId)
  → Guardian emergency override
  → Prevents execution
```

**Voting Mechanics**:
```
Vote Collection:
- Track forVotes, againstVotes, abstainVotes
- Prevent double voting (one vote per member)
- Include delegated voting power automatically

Vote Counting (on execution):
- Required: forVotes > againstVotes
- Required: (forVotes + againstVotes + abstainVotes) >= quorum
- Quorum = totalVotingPower × quorumPercentage

Quorum by Type:
- HighConviction: 30% of total voting power
- Experimental: 20% of total voting power
- Operational: 10% of total voting power
```

**Timelock Enforcement**:
```
Timeline:
T0: Proposal queued
    ETA = now + timelockDelay[proposalType]
    
T0 to ETA: Voting results locked
           Guardian can still cancel
           Public review period
           
ETA to ETA+1week: Proposal can be executed
                  After ETA, not before
                  
ETA+1week: Proposal expires (optional, can extend)
```

**Timelock Delays**:
```
HighConviction: 2 days (172,800 seconds)
  - Major strategic decisions
  - Large fund movements
  - Protocol-level changes
  
Experimental: 1 day (86,400 seconds)
  - New protocol exploration
  - Medium fund movements
  - Moderate risk tolerance
  
Operational: 6 hours (21,600 seconds)
  - Routine DAO operations
  - Tool acquisition
  - Staff compensation
  - Small fund movements
```

## Data Structures

### Proposal Struct
```solidity
struct Proposal {
    uint256 id;                    // Unique identifier
    address proposer;              // Creator
    address recipient;             // Fund recipient
    uint256 amount;                // Transfer amount (wei)
    string description;            // Proposal details
    ProposalType proposalType;     // Risk category
    uint256 startBlock;            // Voting start
    uint256 endBlock;              // Voting end
    uint256 forVotes;              // Cumulative For votes
    uint256 againstVotes;          // Cumulative Against votes
    uint256 abstainVotes;          // Cumulative Abstain votes
    bool cancelled;                // Emergency flag
    bool executed;                 // Completion flag
    uint256 eta;                   // Execution time (timestamp)
    bool queued;                   // Queue status flag
}
```

### State Mappings
```solidity
mapping(address => uint256) _stakes
  → Member address → Stake amount

mapping(uint256 => Proposal) _proposals
  → Proposal ID → Full proposal data

mapping(uint256 => mapping(address => bool)) _hasVoted
  → Proposal ID → Member address → Voted flag

mapping(uint256 => mapping(address => uint8)) _votes
  → Proposal ID → Member address → Vote type

mapping(address => address) _delegations
  → Delegator address → Delegate address

mapping(address => address[]) _delegators
  → Delegate address → Array of delegators

mapping(uint256 => uint256) _executionTimes
  → Proposal ID → Execution timestamp
```

## Flow Diagrams

### Proposal Creation Flow
```
Member with stake ≥ threshold
  ↓
createProposal()
  ├─ Validate: recipient ≠ 0
  ├─ Validate: amount > 0
  ├─ Validate: description not empty
  ├─ Validate: voter power ≥ threshold
  ↓
Create Proposal struct
  ├─ ID = proposalCount++
  ├─ startBlock = now + votingDelay
  ├─ endBlock = startBlock + votingPeriod
  ├─ state = PENDING
  ↓
emit ProposalCreated(id, proposer, recipient, amount, type)
  ↓
Return proposal ID
```

### Voting Flow
```
Member with stake
  ↓
castVote(proposalId, support)
  ├─ Check: proposal not cancelled
  ├─ Check: not already voted
  ├─ Check: proposal is ACTIVE
  ├─ Get: voting power with delegations
  ├─ Check: voting power > 0
  ↓
Record vote
  ├─ Set hasVoted[proposalId][voter] = true
  ├─ Save vote type
  ├─ Add power to vote counters
  ↓
emit VoteCast(proposalId, voter, support, power)
```

### Execution Flow
```
Proposal state = DEFEATED or voting period ended
  ↓
queueProposal(proposalId)
  ├─ Check: not cancelled
  ├─ Check: not queued
  ├─ Check: forVotes > againstVotes
  ├─ Check: quorum reached
  ├─ Calculate ETA = now + timelockDelay[type]
  ↓
Update proposal
  ├─ eta = ETA
  ├─ queued = true
  ↓
emit ProposalQueued(proposalId, eta)
  ↓
⏰ Wait for ETA
  ↓
executeProposal(proposalId)
  ├─ Check: not cancelled
  ├─ Check: not executed
  ├─ Check: now ≥ eta
  ├─ Category = proposalType to fund category mapping
  ↓
treasury.transferFunds(category, recipient, amount)
  ├─ Check: sufficient balance
  ├─ Check: sufficient treasury total
  ├─ Transfer funds via .call{}
  ↓
Set executed = true
  ↓
emit ProposalExecuted(proposalId)
```

## Security Analysis

### Threat Model

#### 1. Whale Dominance
**Threat**: Single large staker controls all decisions
**Mitigation**: Quadratic voting reduces relative influence
```
10× stake = ~3.16× voting power (not 10×)
100× stake = ~10× voting power (not 100×)
```

#### 2. Vote Manipulation
**Threats**: 
- Double voting
- Vote changing after submission
- Front-running vote timing

**Mitigations**:
- Explicit hasVoted tracking
- Immutable vote records
- Votes recorded atomically with state change
- Voting period clearly defined with block numbers

#### 3. Treasury Drains
**Threat**: Malicious proposal drains treasury
**Mitigations**:
- Category limits prevent single category depletion
- Timelock provides cancellation window
- Multiple approval layers (voting + quorum + timelock)
- Guardian emergency override

#### 4. Governance Capture
**Threat**: Bad actor captures voting control
**Mitigations**:
- Minimum voting power for proposals prevents spam
- Multiple proposal types with different thresholds
- Quorum requirements prevent minority takeover
- Guardian role for emergency intervention
- Role-based access control limits single point of failure

#### 5. Delegation Attacks
**Threat**: Fake delegate collects voting power then votes against interest
**Mitigations**:
- Delegations always revocable
- Automatic power updates to delegated amount
- No lock-in period
- Members can redelegate anytime

### Attack Scenarios

#### Scenario 1: Large staker tries to execute malicious proposal

```
Attacker has 50 ETH (major stakeholder)
DAO total: 100 ETH
Attacking power: √50 ≈ 7 (out of total √100 ≈ 10)

Attempt: Create proposal to drain treasury
Result: 
- Needs quorum (30% of voting power = 3.0)
- Needs majority (forVotes > againstVotes)
- Gets ~7 power, others together have ~3 power
- Can pass if others don't participate

Defense 1: Quorum enforcement prevents this
Defense 2: Others can vote against
Defense 3: Guardian can cancel if malicious
Defense 4: 2-day timelock allows emergency intervention
```

#### Scenario 2: Small member delegates to attacker

```
10 small members (1 ETH each) delegate to attacker
Attacker power: √1 + 10×√1 = 1 + 10 = 11
Attacker tries: Create proposal with 11-power supermajority

Defenses:
1. Members can revoke delegations anytime
2. Proposal still needs to pass voting (others can vote)
3. Still needs quorum requirement
4. Timelock gives members time to organize response
5. Guardian can cancel if coordinated attack detected
```

#### Scenario 3: Delegation manipulation in voting

```
Delegator changes mind about vote, wants to delegate to different person
Contract design: Delegated power moves, not person can revoke
Result: Delegator gets power back, can vote directly

This prevents:
- Delegation lock-in
- Collateral damage from bad delegate choice
- Vote suppression via delegation hijacking
```

## Testing Strategy

### Unit Tests
- Individual function behavior
- Boundary conditions
- Input validation
- Event emission

### Integration Tests  
- Multi-contract interactions
- State consistency across components
- Authorization flows
- Treasury and governance interaction

### Scenario Tests
- Complete proposal lifecycle
- Voting with delegations
- Emergency functions
- Parameter updates

### Security Tests
- Access control bypass attempts
- Reentrancy vectors
- Arithmetic overflow/underflow (SafeMath via Solidity 0.8)
- Vote manipulation attempts

## Deployment Considerations

### 1. Initialization
```solidity
// Deploy all contracts
GovernanceToken token = new GovernanceToken();
VotingDelegation delegation = new VotingDelegation(token);
DAOTreasury treasury = new DAOTreasury(100e18, 50e18, 10e18);
DAOAccessControl access = new DAOAccessControl();
DAOGovernance governance = new DAOGovernance(
    address(token),
    address(delegation),
    address(treasury),
    address(access)
);

// Setup initial roles
access.grantRole(GUARDIAN_ROLE, multiSigWallet);
access.grantRole(TIMELOCK_ADMIN_ROLE, multiSigWallet);

// Transfer treasury to governance
treasury.transferOwnership(address(governance));
```

### 2. Parameter Configuration
```solidity
// Set governance parameters
governance.setGovernanceParameters(
    votingDelay = 1,              // ~15 min
    votingPeriod = 50400,         // ~1 week
    proposalThreshold = 1e18,     // 1 ETH equivalent power
    quorumPercentage = 10         // 10% quorum
);

// Set timelock delays
governance.setTimelockDelay(0, 2 days);   // HighConviction
governance.setTimelockDelay(1, 1 day);    // Experimental
governance.setTimelockDelay(2, 6 hours);  // Operational
```

### 3. Initial Funding
```solidity
// Fund treasury with DAO treasury
(address depositor).call{value: 50 ether}(address(treasury), "");

// Or members can deposit to categories
treasury.depositToCategory(0, {value: 30 ether}); // HighConviction
treasury.depositToCategory(1, {value: 15 ether}); // Experimental
treasury.depositToCategory(2, {value: 5 ether});  // Operational
```

## Future Enhancements

### 1. Vote Snapshots
- Record voting power at proposal start block
- Prevent timing attacks
- Support historical queries

### 2. Vote Escrow (veToken)
- Lock tokens for extended voting power boost
- Encourage long-term alignment
- Similar to Curve's ve model

### 3. Cross-Chain Governance
- Multi-chain voting aggregation
- Unified treasury management
- Reduced transaction costs via L2

### 4. Dynamic Parameters
- Self-adjusting quorum based on participation
- Time-weighted voting to incentivize engagement
- Decay mechanics for inactive members

### 5. Advanced Voting
- Ranked choice voting (IRV)
- Liquid democracy chains
- Quadratic funding for grants

### 6. Governance Analytics
- Historical voting patterns
- Member activity tracking
- Proposal success rate analysis

---

**This architecture provides a production-ready governance system suitable for institutional DAOs managing billions in assets.**
