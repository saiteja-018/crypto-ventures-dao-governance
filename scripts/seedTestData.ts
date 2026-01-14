import { ethers } from "hardhat";
import type {
  GovernanceToken,
  VotingDelegation,
  DAOTreasury,
  DAOGovernance,
} from "../typechain-types";

async function main() {
  console.log("Seeding test data for CryptoVentures DAO...\n");

  const [deployer, ...signers] = await ethers.getSigners();

  // Get contract addresses from deployment
  const GOVERNANCE_TOKEN_ADDR = process.env.GOVERNANCE_TOKEN_ADDRESS || "";
  const VOTING_DELEGATION_ADDR = process.env.VOTING_DELEGATION_ADDRESS || "";
  const TREASURY_ADDR = process.env.TREASURY_ADDRESS || "";
  const ACCESS_CONTROL_ADDR = process.env.ACCESS_CONTROL_ADDRESS || "";
  const GOVERNANCE_ADDR = process.env.GOVERNANCE_ADDRESS || "";

  if (!GOVERNANCE_TOKEN_ADDR) {
    console.error("Please set GOVERNANCE_TOKEN_ADDRESS in environment");
    process.exit(1);
  }

  // Connect to contracts
  const GovernanceToken = await ethers.getContractFactory("GovernanceToken");
  const governanceToken = GovernanceToken.attach(GOVERNANCE_TOKEN_ADDR) as unknown as GovernanceToken;

  const VotingDelegation = await ethers.getContractFactory("VotingDelegation");
  const votingDelegation = VotingDelegation.attach(VOTING_DELEGATION_ADDR) as unknown as VotingDelegation;

  const DAOTreasury = await ethers.getContractFactory("DAOTreasury");
  const treasury = DAOTreasury.attach(TREASURY_ADDR) as unknown as DAOTreasury;

  const DAOGovernance = await ethers.getContractFactory("DAOGovernance");
  const governance = DAOGovernance.attach(GOVERNANCE_ADDR) as unknown as DAOGovernance;

  console.log("Creating test members with varying stakes...\n");

  // Create members with different stakes
  const stakeAmounts = [
    { signer: signers[0], amount: ethers.parseEther("20"), name: "Member 1 (Major)" },
    { signer: signers[1], amount: ethers.parseEther("10"), name: "Member 2 (Medium)" },
    { signer: signers[2], amount: ethers.parseEther("5"), name: "Member 3 (Medium)" },
    { signer: signers[3], amount: ethers.parseEther("2"), name: "Member 4 (Small)" },
    { signer: signers[4], amount: ethers.parseEther("1"), name: "Member 5 (Small)" },
  ];

  for (const { signer, amount, name } of stakeAmounts) {
    console.log(`  Depositing ${ethers.formatEther(amount)} ETH for ${name}...`);
    await governanceToken.connect(signer).deposit({ value: amount });
    const votingPower = await governanceToken.getVotingPower(signer.address);
    console.log(`  - Voting power: ${ethers.formatEther(votingPower)}\n`);
  }

  console.log("Creating voting delegations...\n");

  // Create some delegations
  console.log("  Member 4 delegates to Member 1...");
  await votingDelegation.connect(signers[3]).delegate(signers[0].address);

  console.log("  Member 5 delegates to Member 2...\n");
  await votingDelegation.connect(signers[4]).delegate(signers[1].address);

  console.log("Funding treasury with initial capital...\n");

  // Fund treasury categories
  const deposits = [
    { category: 0, amount: ethers.parseEther("30"), name: "High Conviction" },
    { category: 1, amount: ethers.parseEther("15"), name: "Experimental" },
    { category: 2, amount: ethers.parseEther("5"), name: "Operational" },
  ];

  for (const { category, amount, name } of deposits) {
    console.log(`  Depositing ${ethers.formatEther(amount)} ETH to ${name} fund...`);
    await treasury.depositToCategory(category, { value: amount });
  }

  console.log("\nCreating sample proposals...\n");

  // Create sample proposals
  const proposals = [
    {
      recipient: signers[5].address,
      amount: ethers.parseEther("5"),
      description: "High conviction investment in promising startup - $5M allocation",
      type: 0, // HighConviction
      signer: signers[0],
    },
    {
      recipient: signers[6].address,
      amount: ethers.parseEther("2"),
      description: "Experimental bet on emerging DeFi protocol - $2M allocation",
      type: 1, // ExperimentalBet
      signer: signers[1],
    },
    {
      recipient: signers[7].address,
      amount: ethers.parseEther("0.5"),
      description: "Operational expense for DAO infrastructure and tools",
      type: 2, // OperationalExpense
      signer: signers[2],
    },
  ];

  let proposalIds = [];
  for (const { recipient, amount, description, type, signer } of proposals) {
    console.log(`  Creating proposal: "${description}"`);
    const tx = await governance.connect(signer).createProposal(recipient, amount, description, type);
    const receipt = await tx.wait();
    
    const proposalId = await governance.getProposalCount();
    proposalIds.push(Number(proposalId) - 1);
    
    const proposal = await governance.getProposal(proposalIds[proposalIds.length - 1]);
    console.log(`  - Proposal ID: ${proposalIds[proposalIds.length - 1]}`);
    console.log(`  - Amount: ${ethers.formatEther(amount)} ETH`);
    console.log(`  - Recipient: ${recipient}\n`);
  }

  console.log("Advancing blocks to activate proposals...\n");
  
  // Advance blocks to make proposals active
  await ethers.provider.send("hardhat_mine", ["0x2"]);
  console.log("  Blocks advanced - proposals now active\n");

  console.log("Casting sample votes...\n");

  // Cast votes on proposals
  const votes = [
    { proposalId: 0, voter: signers[0], support: 1 }, // For
    { proposalId: 0, voter: signers[1], support: 1 }, // For
    { proposalId: 0, voter: signers[2], support: 0 }, // Against
    { proposalId: 1, voter: signers[1], support: 1 }, // For
    { proposalId: 1, voter: signers[3], support: 2 }, // Abstain
    { proposalId: 2, voter: signers[2], support: 1 }, // For
  ];

  for (let i = 0; i < votes.length; i++) {
    const { proposalId, voter, support } = votes[i];
    const supportNames = ["Against", "For", "Abstain"];
    console.log(`  Member votes ${supportNames[support]} on Proposal ${proposalId}`);
    await governance.connect(voter).castVote(proposalId, support);
  }

  console.log("\n" + "=".repeat(60));
  console.log("TEST DATA SEEDING COMPLETED");
  console.log("=".repeat(60));

  console.log("\nSummary:");
  console.log(`- Members created: ${stakeAmounts.length}`);
  console.log(`- Total stake in DAO: ${ethers.formatEther(
    (await governanceToken.getTotalStake())
  )} ETH`);
  console.log(`- Delegations created: 2`);
  console.log(`- Treasury capital: ${ethers.formatEther(
    await ethers.provider.getBalance(TREASURY_ADDR)
  )} ETH`);
  console.log(`- Sample proposals created: ${proposalIds.length}`);
  console.log(`- Votes cast: ${votes.length}`);

  console.log("\nNext steps:");
  console.log("1. Review proposals with: npx hardhat run scripts/checkProposals.ts");
  console.log("2. Run tests with: npm test");
  console.log("3. Interact with contracts using the addresses above\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
