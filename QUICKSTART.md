# CryptoVentures DAO - Quick Start Guide

## Project Summary

A complete, production-ready governance system for decentralized investment funds implementing:
- ✅ Quadratic voting (prevents whale dominance)
- ✅ Multi-tier proposal system (high-conviction, experimental, operational)
- ✅ Voting delegation with revocation
- ✅ Multi-category treasury with fund limits
- ✅ Role-based access control
- ✅ Time-locked execution with emergency cancellation
- ✅ Complete proposal lifecycle management
- ✅ 30+ comprehensive tests covering all requirements

## Repository Structure

```
crypto-ventures-dao-governance/
├── contracts/
│   ├── governance/
│   │   ├── GovernanceToken.sol        (Stake & voting power - quadratic)
│   │   ├── VotingDelegation.sol       (Vote delegation system)
│   │   └── DAOGovernance.sol          (Proposal lifecycle & voting)
│   ├── treasury/
│   │   └── DAOTreasury.sol            (Multi-category fund management)
│   ├── access/
│   │   └── DAOAccessControl.sol       (Role-based access control)
│   └── interfaces/
│       ├── IGovernanceToken.sol
│       ├── IDelegation.sol
│       ├── IProposal.sol
│       └── ITimelock.sol
├── scripts/
│   ├── deploy.ts                      (One-command deployment)
│   └── seedTestData.ts                (Create test members & proposals)
├── test/
│   ├── DAOGovernance.test.ts          (Governance tests)
│   ├── VotingDelegation.test.ts       (Delegation tests)
│   └── DAOTreasury.test.ts            (Treasury tests)
├── hardhat.config.ts
├── tsconfig.json
├── package.json
├── .env.example
├── .gitignore
├── README.md                          (Full documentation)
├── ARCHITECTURE.md                    (Technical architecture)
├── SECURITY.md                        (Security analysis & threat model)
└── DEPLOYMENT.md                      (Deployment guide)
```

## One-Command Setup

```bash
# 1. Clone repository
git clone <repository-url>
cd crypto-ventures-dao-governance

# 2. Install dependencies
npm install

# 3. Create environment file
cp .env.example .env

# 4. Start local blockchain (Terminal 1)
npx hardhat node

# 5. Deploy contracts (Terminal 2)
npx hardhat run scripts/deploy.ts --network localhost

# 6. Seed test data (Terminal 2)
npx hardhat run scripts/seedTestData.ts --network localhost

# 7. Run tests (Terminal 2)
npm test
```

## Contract Addresses (After Deployment)

```
GovernanceToken:    0x...
VotingDelegation:   0x...
DAOTreasury:        0x...
DAOAccessControl:   0x...
DAOGovernance:      0x...
```

The deployment script outputs all addresses for easy reference.

## Key Features Overview

### 1. Member Governance
```typescript
// Deposit ETH to become DAO member
await governanceToken.deposit({ value: ethers.parseEther("10") });

// Check voting power (quadratic: sqrt(stake))
const power = await governanceToken.getVotingPower(memberAddress);
```

### 2. Create Investment Proposals
```typescript
// Create high-conviction investment proposal
await governance.createProposal(
  "0x742d35Cc...",              // Recipient
  ethers.parseEther("5"),        // 5 ETH
  "Series A investment round",   // Description
  0                              // 0=HighConviction
);
```

### 3. Vote with Quadratic Voting
```typescript
// Vote FOR (1), AGAINST (0), ABSTAIN (2)
await governance.castVote(proposalId, 1);

// Voting power = sqrt(stake)
// Prevents whale dominance
// 100× stake = ~10× voting power (not 100×)
```

### 4. Delegate Voting Power
```typescript
// Delegate to trusted member
await votingDelegation.delegate(trustedMember.address);

// Check total power (own + delegated)
const totalPower = await votingDelegation
  .getVotingPowerWithDelegation(delegate.address);

// Revoke anytime
await votingDelegation.revokeDelegation();
```

### 5. Proposal Lifecycle
```
1. CREATE: Member creates proposal
2. VOTE: Voting period (~1 week)
3. QUEUE: If approved, queue for execution
4. WAIT: Timelock period (6h-2d depending on type)
5. EXECUTE: Anyone can execute after timelock

Guardian can CANCEL at any time before execution
```

### 6. Multi-Tier Treasury
```
High Conviction (100 ETH limit)
├── 2-day timelock
├── 30% quorum required
└── Major investments

Experimental (50 ETH limit)
├── 1-day timelock
├── 20% quorum required
└── New protocols

Operational (10 ETH limit)
├── 6-hour timelock
├── 10% quorum required
└── DAO operations
```

## Testing

### Run All Tests
```bash
npm test
```

### Run Specific Suite
```bash
# Test governance
npx hardhat test test/DAOGovernance.test.ts

# Test delegation
npx hardhat test test/VotingDelegation.test.ts

# Test treasury
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

## Core Requirements Met

All 30 core requirements implemented:

### Governance & Voting
- ✅ Quadratic voting prevents whale dominance
- ✅ Members stake ETH for voting power
- ✅ Vote casting (for, against, abstain)
- ✅ One vote per member per proposal
- ✅ Prevent vote changes after casting
- ✅ Voting periods with start/end blocks

### Proposals
- ✅ Create proposals with recipient/amount/description
- ✅ Unique proposal identifiers
- ✅ Three proposal types (high-conviction, experimental, operational)
- ✅ Different approval thresholds and quorum per type
- ✅ Proposal spam prevention (minimum voting power)

### Delegation
- ✅ Delegate voting power to trusted member
- ✅ Revocable delegations
- ✅ Automatic inclusion in delegate votes
- ✅ No manual action needed from delegator

### Proposal Lifecycle
- ✅ Complete state machine (Pending → Active → Queued → Executed/Defeated)
- ✅ Draft/Pending → Active (voting period)
- ✅ Queued if approved
- ✅ Defeated if rejected
- ✅ Cancelled for emergencies

### Timelock & Execution
- ✅ Minimum time delay before execution (configurable per type)
- ✅ Proposal cancellation during timelock window
- ✅ Authorized roles only for execution
- ✅ Prevent multiple executions
- ✅ Automatic fund transfer on execution

### Treasury
- ✅ Track multiple fund allocations (high-conviction, experimental, operational)
- ✅ Category-specific balance limits
- ✅ Fast-track for operational expenses
- ✅ Secure fund transfers
- ✅ Graceful failure if insufficient funds

### Security & Control
- ✅ Emergency proposal cancellation (guardian)
- ✅ Role-based access control (proposer, voter, executor, guardian)
- ✅ System pause capability
- ✅ Multiple roles per member supported
- ✅ Clear separation of powers

### Events & Transparency
- ✅ Events for all critical actions
- ✅ Indexed parameters (proposalId, voter, proposalType)
- ✅ Historical voting records queryable
- ✅ Proposal state queryable
- ✅ Complete audit trail

### Edge Cases
- ✅ Zero votes on proposals
- ✅ Tie voting results (defeated)
- ✅ Expired proposals
- ✅ Insufficient treasury funds
- ✅ Consistent voting power calculation

## Usage Examples

### Example 1: Create and Vote on Proposal

```typescript
// 1. Deployer address (admin)
const [deployer, member1, member2, recipient] = await ethers.getSigners();

// 2. Members deposit ETH
await governanceToken.connect(member1).deposit({ 
  value: ethers.parseEther("20") 
});
await governanceToken.connect(member2).deposit({ 
  value: ethers.parseEther("10") 
});

// 3. Create proposal
const tx = await governance.connect(member1).createProposal(
  recipient.address,
  ethers.parseEther("5"),
  "Invest in Series A round",
  0 // HighConviction
);

// 4. Advance blocks for voting to start
await ethers.provider.send("hardhat_mine", ["0x2"]);

// 5. Vote FOR
await governance.connect(member1).castVote(proposalId, 1); // 1 = For
await governance.connect(member2).castVote(proposalId, 1); // 1 = For

// 6. Advance past voting period
await ethers.provider.send("hardhat_mine", ["0xc500"]);

// 7. Fund treasury
const operationalCategory = 2;
await treasury.depositToCategory(operationalCategory, {
  value: ethers.parseEther("10")
});

// 8. Queue proposal
await governance.queueProposal(proposalId);

// 9. Wait for timelock (2 days for HighConviction)
await ethers.provider.send("evm_increaseTime", ["0x15180"]); // 2 days
await ethers.provider.send("hardhat_mine", ["0x1"]);

// 10. Execute proposal
await governance.executeProposal(proposalId);

// 11. Verify execution
const proposal = await governance.getProposal(proposalId);
expect(proposal.executed).to.be.true;
```

### Example 2: Delegation

```typescript
// Member A delegates to Member B
await votingDelegation.connect(memberA).delegate(memberB.address);

// Member B now has combined voting power
const totalPower = await votingDelegation
  .getVotingPowerWithDelegation(memberB.address);

// Check delegators
const delegators = await votingDelegation.getDelegators(memberB.address);
console.log("Delegators:", delegators);

// Member A can revoke anytime
await votingDelegation.connect(memberA).revokeDelegation();

// Member A's power returned
```

## Configuration

Key parameters in `hardhat.config.ts`:

```typescript
// Voting parameters
votingDelay = 1;              // Blocks before voting starts
votingPeriod = 50400;         // Voting duration blocks (~1 week)
proposalThreshold = 1e18;     // Min voting power to propose

// Quorum percentages
quorumPercentage[0] = 30;     // HighConviction: 30%
quorumPercentage[1] = 20;     // Experimental: 20%
quorumPercentage[2] = 10;     // Operational: 10%

// Timelock delays
timelockDelay[0] = 2 days;    // HighConviction: 2 days
timelockDelay[1] = 1 day;     // Experimental: 1 day
timelockDelay[2] = 6 hours;   // Operational: 6 hours

// Treasury limits
HighConvictionLimit = 100 ETH;
ExperimentalLimit = 50 ETH;
OperationalLimit = 10 ETH;
```

## Troubleshooting

### "Proposal is not in active state"
- Voting hasn't started yet
- Need to advance blocks: `await ethers.provider.send("hardhat_mine", ["0x2"])`

### "Insufficient voting power to propose"
- Member doesn't have enough stake
- Increase deposit: `await governanceToken.deposit({value: ethers.parseEther("10")})`

### "Timelock not expired"
- Time-locked period hasn't passed
- Advance time: `await ethers.provider.send("evm_increaseTime", ["<seconds>"])`

### "Insufficient balance in category"
- Treasury category empty
- Fund category: `await treasury.depositToCategory(category, {value: amount})`

### Test failures
1. Check block numbers advanced correctly
2. Verify timelock periods passed
3. Ensure all roles granted
4. Check treasury funded

## File Descriptions

### Smart Contracts

| File | Purpose |
|------|---------|
| GovernanceToken.sol | Stake management & quadratic voting power |
| VotingDelegation.sol | Vote delegation with revocation |
| DAOGovernance.sol | Main governance (proposals, voting, execution) |
| DAOTreasury.sol | Multi-category fund management |
| DAOAccessControl.sol | Role-based permissions |

### Tests

| File | Purpose |
|------|---------|
| DAOGovernance.test.ts | Proposal lifecycle, voting, timelock |
| VotingDelegation.test.ts | Delegation, revocation, voting power |
| DAOTreasury.test.ts | Fund management, transfers, limits |

### Documentation

| File | Purpose |
|------|---------|
| README.md | Full feature documentation |
| ARCHITECTURE.md | Technical system design |
| SECURITY.md | Threat model & security analysis |
| DEPLOYMENT.md | Deployment instructions |

## Next Steps

1. **Review Code**: Start with [contracts/governance/DAOGovernance.sol](contracts/governance/DAOGovernance.sol)
2. **Run Tests**: `npm test` to verify all functionality
3. **Deploy Locally**: `npx hardhat run scripts/deploy.ts --network localhost`
4. **Create Proposals**: Use seeded test data to interact with governance
5. **Read Docs**: See [README.md](README.md) for comprehensive guide

## Support

For questions or issues:
1. Check [README.md](README.md) for full documentation
2. Review [ARCHITECTURE.md](ARCHITECTURE.md) for design details
3. See [SECURITY.md](SECURITY.md) for threat model
4. Run tests: `npm test`
5. Check deployment logs for contract addresses

---

**Ready to build DAOs with institutional-grade governance!**

Built with Hardhat, Solidity 0.8.24, and OpenZeppelin Contracts
