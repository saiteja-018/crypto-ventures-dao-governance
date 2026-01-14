# CryptoVentures DAO Governance System

A comprehensive, production-ready governance system for decentralized investment funds, implementing advanced governance patterns used by major DAOs like Compound, Aave, and MakerDAO.

## Overview

CryptoVentures DAO is a decentralized investment fund where token holders collectively manage treasury allocations and make investment decisions through a robust governance system. This implementation solves real operational challenges including:

- **Decision Bottlenecks**: Efficient proposal lifecycle with multiple tiers of urgency
- **Member Exclusion**: Every stake holder has proportional voting power
- **Execution Risks**: Time-locked execution prevents hasty decisions and allows emergency intervention
- **Inefficient Approvals**: Risk-based approval thresholds for different proposal types

## Key Features

### 1. **Stake-Based Governance**
- Members deposit ETH to receive governance power
- Quadratic voting (voting power = √stake) prevents whale dominance
- Transparent voting power calculations without requiring active participation

### 2. **Comprehensive Proposal Lifecycle**
```
Draft/Pending → Active (voting period) → Queued → Executed
                                      ↓
                                   Defeated (if rejected)
                                      ↓
                                   Cancelled (emergency)
```

### 3. **Multi-Tier Proposal System**
Three proposal types with different risk profiles:

| Type | Timelock | Quorum | Use Case |
|------|----------|--------|----------|
| High Conviction | 2 days | 30% | Major investments (>$5M) |
| Experimental Bet | 1 day | 20% | New protocol exploration (>$2M) |
| Operational Expense | 6 hours | 10% | DAO operations (<$1M) |

### 4. **Voting Delegation**
- Members can delegate their voting power to trusted members
- Delegates automatically receive delegated votes when voting
- Delegations are revocable at any time
- Prevents double voting and maintains vote integrity

### 5. **Multi-Category Treasury**
- Independent fund allocations (High Conviction, Experimental, Operational)
- Category-specific balance limits prevent overspending
- Automatic fund routing based on proposal type
- Graceful failure handling for insufficient funds

### 6. **Role-Based Access Control**
- **Proposer**: Can create new proposals (requires minimum voting power)
- **Voter**: All stake holders can vote
- **Executor**: Executes approved proposals after timelock
- **Guardian**: Can cancel malicious/erroneous proposals
- **Timelock Admin**: Configures governance parameters

### 7. **Security & Emergency Controls**
- Time-locked execution provides security window (minimum 6 hours)
- Guardian emergency cancellation for critical security issues
- Configurable timelock delays per proposal type
- Prevents same proposal from executing multiple times
- One vote per member per proposal (no vote changes)

### 8. **Complete Event Emission**
All critical actions emit indexed events for transparency:
- Proposal creation (includes proposalId, proposer, proposalType)
- Votes cast (includes proposalId, voter, support, votingPower)
- Delegations created/revoked
- Proposal state transitions
- Treasury transfers with category tracking

## Architecture

### Contract Structure

```
contracts/
├── governance/
│   ├── GovernanceToken.sol       # Stake management & voting power (quadratic)
│   ├── VotingDelegation.sol       # Delegation system with revocation
│   └── DAOGovernance.sol          # Main governance engine with timelock
├── treasury/
│   └── DAOTreasury.sol            # Multi-category fund management
├── access/
│   └── DAOAccessControl.sol       # Role-based access control
└── interfaces/
    ├── IGovernanceToken.sol
    ├── IDelegation.sol
    ├── IProposal.sol
    └── ITimelock.sol
```

### Component Interactions

```
┌─────────────────────────────────────────────────────────┐
│                    DAOGovernance                         │
│         (Proposal Lifecycle & Voting Management)        │
└──────────────┬──────────────────────────────────────────┘
               │
       ┌───────┴────────┬──────────────┬──────────────┐
       │                │              │              │
       ▼                ▼              ▼              ▼
┌────────────┐  ┌──────────────┐  ┌────────────┐  ┌──────────────┐
│Governance  │  │   Voting     │  │    DAO     │  │   Access     │
│   Token    │  │ Delegation   │  │  Treasury  │  │   Control    │
└────────────┘  └──────────────┘  └────────────┘  └──────────────┘
  (Voting Power)  (Vote Proxy)    (Fund Safety)    (Permissions)
```

### Voting Power Calculation (Quadratic)

To prevent whale dominance:
```
Voting Power = √(Stake in ETH) × Precision Factor

Examples:
- 1 ETH stake → ~1 voting power
- 4 ETH stake → ~2 voting power  
- 16 ETH stake → ~4 voting power
- 100 ETH stake → ~10 voting power (not 100x)
```

This quadratic mechanism reduces the relative influence of large stakers while maintaining their advantage.

## Installation & Setup

### Prerequisites
- Node.js >= 18.0.0
- npm >= 9.0.0
- Git

### Step 1: Clone and Install

```bash
git clone https://github.com/yourusername/crypto-ventures-dao-governance.git
cd crypto-ventures-dao-governance

npm install
```

### Step 2: Configure Environment

```bash
cp .env.example .env
# Edit .env and set your configuration
```

### Step 3: Start Local Blockchain

```bash
# In terminal 1
npx hardhat node
```

### Step 4: Deploy Contracts

```bash
# In terminal 2
npx hardhat run scripts/deploy.ts --network localhost
```

The deployment script will output all contract addresses.

### Step 5: Seed Test Data (Optional)

```bash
# Create test members, stakes, and sample proposals
npx hardhat run scripts/seedTestData.ts --network localhost
```

## Usage Examples

### 1. Depositing Stake

```typescript
const governanceToken = await ethers.getContractAt(
  "GovernanceToken",
  GOVERNANCE_TOKEN_ADDRESS
);

// Deposit 10 ETH to receive voting power
await governanceToken.deposit({ value: ethers.parseEther("10") });

// Check voting power
const votingPower = await governanceToken.getVotingPower(member.address);
console.log("Voting Power:", votingPower.toString());
```

### 2. Creating a Proposal

```typescript
const governance = await ethers.getContractAt(
  "DAOGovernance",
  GOVERNANCE_ADDRESS
);

const proposalTx = await governance.createProposal(
  "0x742d35Cc6634C0532925a3b844Bc9e7595f42bE4", // recipient
  ethers.parseEther("5"),                          // amount (5 ETH)
  "Investment in promising startup series A round",  // description
  0                                                 // 0=HighConviction, 1=Experimental, 2=Operational
);

// Get proposal ID from event
const receipt = await proposalTx.wait();
const proposalId = 0; // Example
```

### 3. Voting on a Proposal

```typescript
// Vote FOR (1), AGAINST (0), or ABSTAIN (2)
await governance.castVote(
  proposalId,  // Proposal ID
  1            // 1 = For
);

// Check if already voted
const hasVoted = await governance.hasVoted(proposalId, member.address);
console.log("Has Voted:", hasVoted);
```

### 4. Delegating Voting Power

```typescript
const votingDelegation = await ethers.getContractAt(
  "VotingDelegation",
  VOTING_DELEGATION_ADDRESS
);

// Delegate to trusted member
await votingDelegation.delegate(trustedMember.address);

// Check voting power with delegations
const totalPower = await votingDelegation.getVotingPowerWithDelegation(
  delegate.address
);

// Revoke delegation later
await votingDelegation.revokeDelegation();
```

### 5. Queuing and Executing Proposals

```typescript
// After voting period ends and proposal passes
// 1. Queue the proposal (after votes counted and quorum verified)
await governance.queueProposal(proposalId);

// 2. Wait for timelock to expire
// For HighConviction: 2 days
// For Experimental: 1 day
// For Operational: 6 hours

// 3. Execute the proposal
await governance.executeProposal(proposalId);

// Funds are transferred from treasury to recipient
```

### 6. Emergency Proposal Cancellation (Guardian Only)

```typescript
// Guardian can cancel malicious proposals
await governance.cancelProposal(proposalId);
```

## Testing

### Run All Tests

```bash
npm test
```

### Run Specific Test Suite

```bash
# Test governance functionality
npx hardhat test test/DAOGovernance.test.ts

# Test voting delegation
npx hardhat test test/VotingDelegation.test.ts

# Test treasury management
npx hardhat test test/DAOTreasury.test.ts
```

### Generate Gas Report

```bash
REPORT_GAS=true npm test
```

### Coverage Report

```bash
npm run coverage
```

## Test Coverage

The test suite includes comprehensive coverage of:

### Governance Token Tests (10+ tests)
- ✅ Deposit and withdrawal functionality
- ✅ Voting power calculation (quadratic)
- ✅ Whale dominance prevention
- ✅ Stake tracking and querying

### Voting Delegation Tests (15+ tests)
- ✅ Delegation creation and revocation
- ✅ Voting power including delegations
- ✅ Multiple delegators to single delegatee
- ✅ Delegation list management
- ✅ Prevention of self-delegation
- ✅ Re-delegation after revocation

### Proposal Lifecycle Tests (20+ tests)
- ✅ Proposal creation with validation
- ✅ Spam prevention (minimum voting power required)
- ✅ Voting with different vote types
- ✅ Prevention of double voting
- ✅ Active period enforcement
- ✅ Proposal state transitions
- ✅ Queue approval validation
- ✅ Timelock enforcement
- ✅ Execution with funds transfer
- ✅ Prevention of double execution
- ✅ Emergency cancellation

### Treasury Tests (15+ tests)
- ✅ Category-specific balance limits
- ✅ Fund deposits to categories
- ✅ Safe withdrawals with validation
- ✅ Multi-category independence
- ✅ Authorization checks
- ✅ Graceful failure on insufficient funds
- ✅ Balance limit updates

### Edge Cases (10+ tests)
- ✅ Zero votes on proposals
- ✅ Tie voting results
- ✅ Expired proposals
- ✅ Proposals without quorum
- ✅ Delegation with zero stake
- ✅ Multiple delegations to same member
- ✅ Role-based access control

## Design Decisions & Trade-offs

### 1. Quadratic Voting vs. Linear Voting
**Decision**: Quadratic voting (power = √stake)

**Rationale**:
- Prevents whale dominance: A 100× staker only gets ~10× voting power
- Maintains meritocracy: Larger stakeholders still have more influence
- Economically optimal: Reduces incentive to accumulate large stakes purely for voting

**Trade-off**: Slightly more complex math, but critical for DAO health

### 2. Block-Based vs. Time-Based Voting Periods
**Decision**: Block-based voting periods (using block.number)

**Rationale**:
- Deterministic and chain-agnostic
- Works across all networks regardless of block time
- Easier testing and simulation

**Trade-off**: Requires advance knowledge of block time to estimate duration

### 3. Timelock Per Proposal Type vs. Global Timelock
**Decision**: Per-proposal-type timelock

**Rationale**:
- Risk-proportional delays: Critical decisions get longer review periods
- Operational efficiency: Routine expenses don't need 2-day delays
- Economic incentives preserved: High-risk doesn't exceed necessary delays

**Trade-off**: More complex configuration but better aligned with proposal risk

### 4. Delegation Without Vote Snapshots
**Decision**: Real-time delegation without vote snapshots

**Rationale**:
- Simpler implementation
- Delegates always have current voting power
- No timing attacks around vote snapshots

**Trade-off**: Delegates can't change vote after initial delegation (by design)

### 5. Revocable Delegations
**Decision**: Full revocation support

**Rationale**:
- Maintains member autonomy
- Prevents delegation from becoming permanent power transfer
- Allows members to reclaim voting rights if needed

**Trade-off**: Delegates must manage delegations carefully

## Security Considerations

### 1. Reentrancy Protection
All external calls properly ordered: checks → effects → interactions

### 2. Vote Integrity
- One vote per member per proposal (no changes allowed)
- Voting power calculated at proposal state transition
- Delegation changes don't affect past votes

### 3. Fund Safety
- Treasury transfers require governance approval
- Balance limits prevent category overspending
- Separate fund categories isolate risk

### 4. Access Control
- Minimal role permissions
- Guardian override for emergencies
- Timelock admin for parameter changes only

### 5. Input Validation
- Non-zero address checks for all participants
- Amount validation to prevent edge cases
- Category validation for treasury operations

### 6. State Machine Integrity
- Proposal states follow strict transitions
- State changes atomic and irreversible (except cancellation)
- No proposal can execute twice

## Gas Optimization

The implementation includes several gas optimizations:

1. **Efficient Storage**: Uses mapping for O(1) lookups
2. **Minimal State**: Only necessary state tracked
3. **Delegators Array Management**: Efficient removal using swap-and-pop
4. **Square Root Calculation**: Optimized Newton's method
5. **Event Indexing**: Strategic parameter indexing for efficient filtering

### Typical Gas Costs

| Operation | Estimated Gas |
|-----------|---------------|
| Deposit | ~65,000 |
| Create Proposal | ~85,000 |
| Cast Vote | ~75,000 |
| Delegate | ~95,000 |
| Queue Proposal | ~45,000 |
| Execute Proposal | ~55,000 |

## Governance Parameters

### Configurable Settings

All parameters configurable by TIMELOCK_ADMIN_ROLE:

```solidity
votingDelay = 1;                    // Blocks before voting starts
votingPeriod = 50400;               // Voting duration in blocks (~1 week)
proposalThreshold = 1e18;           // Min voting power to propose
quorumPercentage = 10;              // Required quorum percentage

timelockDelays[HighConviction] = 2 days;
timelockDelays[Experimental] = 1 day;
timelockDelays[Operational] = 6 hours;

quorumRequirements[HighConviction] = 30%;
quorumRequirements[Experimental] = 20%;
quorumRequirements[Operational] = 10%;
```

## FAQ

### Q: What happens if a proposal reaches a tie in voting?
A: It's considered defeated. Ties require unanimous "for" votes to pass.

### Q: Can I vote if I've delegated my voting power?
A: No, delegated power is transferred to the delegate. Revoke your delegation first if you want to vote.

### Q: What's the minimum voting power to create a proposal?
A: Defined by `proposalThreshold`, default 1 ETH equivalent. Can be changed by governance.

### Q: Can I change my vote after casting?
A: No, votes are locked once cast. This prevents vote manipulation.

### Q: What happens to delegations if I withdraw my stake?
A: Delegations remain, but your voting power becomes zero. You can revoke the delegation anytime.

### Q: How long do I need to wait to execute a proposal?
A: Depends on proposal type:
- High Conviction: 2 days
- Experimental: 1 day  
- Operational: 6 hours

Plus the voting period (usually ~1 week).

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - See LICENSE file for details

## Deployed Contracts

### Mainnet
(To be deployed)

### Sepolia Testnet
(To be deployed)

## Support

For questions, issues, or discussions:
- Open an issue on GitHub
- Join our Discord community
- Email: governance@cryptoventures.dao

## References

### Governance Patterns
- [Compound Governance](https://compound.finance/governance)
- [Aave Governance Protocol](https://docs.aave.com/governance/)
- [MakerDAO Governance](https://governance.makerdao.com)
- [OpenZeppelin Governor](https://docs.openzeppelin.com/contracts/4.x/governance)

### Voting Theory
- [Quadratic Voting](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2003531)
- [Conviction Voting](https://medium.com/giveth/conviction-voting-a-novel-continuous-collaborative-decision-making-alternative-to-linear-voting-88e30e9a448c)
- [Liquid Democracy](https://www.researchgate.net/publication/303891699_Liquid_Democracy_Concept_Approaches_and_Challenges)

---

**Built with ❤️ for the CryptoVentures DAO Community**
