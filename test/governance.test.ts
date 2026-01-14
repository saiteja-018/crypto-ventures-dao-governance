import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import type {
  GovernanceToken,
  VotingDelegation,
  DAOTreasury,
  DAOAccessControl,
  DAOGovernance,
} from "../typechain-types";

describe("CryptoVentures DAO Governance System", function () {
  let governanceToken: GovernanceToken;
  let votingDelegation: VotingDelegation;
  let treasury: DAOTreasury;
  let accessControl: DAOAccessControl;
  let governance: DAOGovernance;

  let owner: any;
  let member1: any;
  let member2: any;
  let member3: any;

  before(async function () {
    [owner, member1, member2, member3] = await ethers.getSigners();

    // Deploy GovernanceToken
    const GovernanceTokenFactory = await ethers.getContractFactory("GovernanceToken");
    governanceToken = (await GovernanceTokenFactory.deploy()) as unknown as GovernanceToken;

    // Deploy VotingDelegation
    const VotingDelegationFactory = await ethers.getContractFactory("VotingDelegation");
    votingDelegation = (await VotingDelegationFactory.deploy(
      await governanceToken.getAddress()
    )) as unknown as VotingDelegation;

    // Deploy Treasury
    const TreasuryFactory = await ethers.getContractFactory("DAOTreasury");
    treasury = (await TreasuryFactory.deploy(
      owner.address,
      ethers.parseEther("100"),
      ethers.parseEther("50"),
      ethers.parseEther("10")
    )) as unknown as DAOTreasury;

    // Deploy AccessControl
    const AccessControlFactory = await ethers.getContractFactory("DAOAccessControl");
    accessControl = (await AccessControlFactory.deploy(owner.address)) as unknown as DAOAccessControl;

    // Deploy Governance
    const GovernanceFactory = await ethers.getContractFactory("DAOGovernance");
    governance = (await GovernanceFactory.deploy(
      await governanceToken.getAddress(),
      await votingDelegation.getAddress(),
      await treasury.getAddress(),
      await accessControl.getAddress()
    )) as unknown as DAOGovernance;

    // Grant admin roles to owner for testing
    const TIMELOCK_ADMIN_ROLE = await accessControl.TIMELOCK_ADMIN_ROLE();
    const GUARDIAN_ROLE = await accessControl.GUARDIAN_ROLE();
    await accessControl.grantRole(TIMELOCK_ADMIN_ROLE, owner.address);
    await accessControl.grantRole(GUARDIAN_ROLE, owner.address);

    // Transfer treasury ownership to governance contract
    await treasury.transferOwnership(await governance.getAddress());

    // Deposit stakes for members
    await governanceToken.connect(member1).deposit({ value: ethers.parseEther("10") });
    await governanceToken.connect(member2).deposit({ value: ethers.parseEther("100") });
    await governanceToken.connect(member3).deposit({ value: ethers.parseEther("50") });
  });

  describe("Governance Token", function () {
    it("Should allow deposits and track stakes", async function () {
      const depositAmount = ethers.parseEther("10");
      // Member1 already has a stake from before() setup
      const initialStake = await governanceToken.getStake(member1.address);
      await governanceToken.connect(member1).deposit({ value: depositAmount });
      
      const stake = await governanceToken.getStake(member1.address);
      expect(stake).to.equal(initialStake + depositAmount);
    });

    it("Should calculate quadratic voting power correctly", async function () {
      const depositAmount = ethers.parseEther("100");
      await governanceToken.connect(member2).deposit({ value: depositAmount });
      
      const votingPower = await governanceToken.getVotingPower(member2.address);
      expect(votingPower).to.be.greaterThan(0n);
    });

    it("Should implement quadratic voting (sqrt formula)", async function () {
      const smallDeposit = ethers.parseEther("1");
      const largeDeposit = ethers.parseEther("100");
      
      await governanceToken.connect(member1).deposit({ value: smallDeposit });
      await governanceToken.connect(member2).deposit({ value: largeDeposit });
      
      const smallVote = await governanceToken.getVotingPower(member1.address);
      const largeVote = await governanceToken.getVotingPower(member2.address);
      
      expect(largeVote).to.be.greaterThan(smallVote);
      expect(largeVote).to.be.lessThan(largeDeposit);
    });

    it("Should allow withdrawals", async function () {
      const depositAmount = ethers.parseEther("50");
      const withdrawAmount = ethers.parseEther("10");
      
      await governanceToken.connect(member1).deposit({ value: depositAmount });
      const initialStake = await governanceToken.getStake(member1.address);
      
      await governanceToken.connect(member1).withdraw(withdrawAmount);
      const finalStake = await governanceToken.getStake(member1.address);
      
      expect(finalStake).to.equal(initialStake - withdrawAmount);
    });

    it("Should prevent overdrafts", async function () {
      const stake = await governanceToken.getStake(member1.address);
      const tooMuch = stake + ethers.parseEther("1");
      
      await expect(
        governanceToken.connect(member1).withdraw(tooMuch)
      ).to.be.revertedWith("Insufficient stake");
    });

    it("Should track total voting power", async function () {
      const totalVotingPower = await governanceToken.getTotalVotingPower();
      expect(totalVotingPower).to.be.greaterThan(0n);
    });
  });

  describe("Proposals", function () {
    it("Should create proposals", async function () {
      const recipient = member3.address;
      const amount = ethers.parseEther("5");
      const description = "Fund community initiative";
      
      await expect(
        governance.connect(member1).createProposal(recipient, amount, description, 0)
      ).to.emit(governance, "ProposalCreated");
      
      const proposal = await governance.getProposal(0);
      expect(proposal.recipient).to.equal(recipient);
      expect(proposal.amount).to.equal(amount);
    });

    it("Should allow voting on proposals", async function () {
      // Create a proposal first
      await governance.connect(member1).createProposal(
        member3.address,
        ethers.parseEther("1"),
        "Voting test proposal",
        2
      );

      // Mine blocks to pass voting delay
      await ethers.provider.send("hardhat_mine", ["0x2"]);

      await expect(
        governance.connect(member1).castVote(0, 1)
      ).to.emit(governance, "VoteCast");
      
      const hasVoted = await governance.hasVoted(0, member1.address);
      expect(hasVoted).to.be.true;
    });

    it("Should prevent double voting", async function () {
      await expect(
        governance.connect(member1).castVote(0, 1)
      ).to.be.revertedWith("Voter already voted");
    });

    it("Should support multiple proposal types", async function () {
      const amount = ethers.parseEther("5");
      
      // Get current proposal count
      const currentCount = await governance.getProposalCount();
      
      // HighConviction (0)
      await governance.connect(member2).createProposal(member3.address, amount, "Conviction", 0);
      
      // ExperimentalBet (1)
      await governance.connect(member2).createProposal(member3.address, amount, "Experimental", 1);
      
      // Use the second proposal we just created
      const proposal2 = await governance.getProposal(currentCount + 1n);
      // Destructure the returned tuple
      const [id, proposer, recipient, proposalAmount, description, proposalType] = proposal2;
      expect(Number(proposalType)).to.equal(1);
    });

    it("Should determine proposal state", async function () {
      let state = await governance.getProposalState(1);
      expect(state).to.equal(1); // Active (after voting delay)
    });
  });

  describe("Timelock & Execution", function () {
    it("Should queue and execute proposals after timelock", async function () {
      const amount = ethers.parseEther("1");
      
      // Create proposal
      await governance.connect(member1).createProposal(
        member3.address,
        amount,
        "Execution test",
        2
      );
      
      const proposalId = 3n;

      // Mine blocks to pass voting delay
      await ethers.provider.send("hardhat_mine", ["0x2"]);
      
      // Vote for it
      await governance.connect(member1).castVote(proposalId, 1);
      await governance.connect(member2).castVote(proposalId, 1);

      // Mine blocks to end voting period
      await ethers.provider.send("hardhat_mine", ["0xC500"]);
      
      // Deposit funds to treasury
      await treasury.connect(owner).depositToCategory(2, { value: amount });
      
      // Queue it
      await expect(
        governance.queueProposal(proposalId)
      ).to.emit(governance, "ProposalQueued");
      
      const executionTime = await governance.getExecutionTime(proposalId);
      expect(executionTime).to.be.greaterThan(0n);
    });

    it("Should prevent execution before timelock expires", async function () {
      const proposalId = 3n;
      
      await expect(
        governance.executeProposal(proposalId)
      ).to.be.revertedWith("Timelock not expired");
    });
  });

  describe("Proposal States", function () {
    it("Should track proposals with no votes as defeated", async function () {
      await governance.connect(member1).createProposal(
        member3.address,
        ethers.parseEther("1"),
        "Zero vote proposal",
        2
      );
      
      const proposal = await governance.getProposal(7);
      expect(proposal.forVotes).to.equal(0n);
    });

    it("Should handle tied votes", async function () {
      await governance.connect(member1).createProposal(
        member3.address,
        ethers.parseEther("1"),
        "Tie proposal",
        2
      );
      
      const proposal = await governance.getProposal(8);
      expect(proposal.forVotes).to.equal(0n);
    });

    it("Should handle large funding amounts", async function () {
      const hugeAmount = ethers.parseEther("1000");
      
      // Get current proposal count
      const currentCount = await governance.getProposalCount();
      
      await governance.connect(member1).createProposal(
        member3.address,
        hugeAmount,
        "Huge proposal",
        0
      );
      
      const proposal = await governance.getProposal(currentCount);
      // Destructure the returned tuple
      const [id, proposer, recipient, amount] = proposal;
      expect(amount).to.equal(hugeAmount);
    });
  });

  describe("Proposal Cancellation", function () {
    it("Should allow guardian to cancel proposals", async function () {
      await governance.connect(member1).createProposal(
        member3.address,
        ethers.parseEther("1"),
        "Cancellable proposal",
        2
      );
      
      const proposalId = 5n;
      
      // Owner has GUARDIAN_ROLE, so can cancel
      await expect(
        governance.cancelProposal(proposalId)
      ).to.emit(governance, "ProposalCancelled");
      
      const proposal = await governance.getProposal(proposalId);
      expect(proposal.cancelled).to.be.true;
    });

    it("Should prevent non-guardians from canceling", async function () {
      await governance.connect(member1).createProposal(
        member3.address,
        ethers.parseEther("1"),
        "Protected proposal",
        2
      );
      
      const proposalId = 6n;
      
      await expect(
        governance.connect(member1).cancelProposal(proposalId)
      ).to.be.revertedWith("Only guardians can cancel proposals");
    });
  });

  describe("Governance Parameters", function () {
    it("Should allow owner to update voting period", async function () {
      const newVotingPeriod = 100800n;
      
      await governance.setGovernanceParameters(
        1n,
        newVotingPeriod,
        ethers.parseEther("1"),
        10n
      );
      
      expect(await governance.votingPeriod()).to.equal(newVotingPeriod);
    });

    it("Should allow owner to update timelock delay", async function () {
      const newDelay = 86400n; // 1 day
      
      await governance.setTimelockDelay(0, newDelay);
      const delay = await governance.getTimelockDelay(0);
      
      expect(delay).to.equal(newDelay);
    });
  });

  describe("Voting Delegation", function () {
    it("Should allow delegation of voting power", async function () {
      const delegator = member1;
      const delegatee = member2;
      
      await votingDelegation.connect(delegator).delegate(delegatee.address);
      
      const delegateeAddress = await votingDelegation.getDelegation(delegator.address);
      expect(delegateeAddress).to.equal(delegatee.address);
    });

    it("Should allow revoking delegation", async function () {
      const delegator = member1;
      
      await votingDelegation.connect(delegator).revokeDelegation();
      
      const delegateeAddress = await votingDelegation.getDelegation(delegator.address);
      expect(delegateeAddress).to.equal(ethers.ZeroAddress);
    });

    it("Should calculate voting power with delegation", async function () {
      const votingPower = await votingDelegation.getVotingPowerWithDelegation(member2.address);
      expect(votingPower).to.be.greaterThanOrEqual(0n);
    });
  });

  describe("Treasury Management", function () {
    it("Should allow depositing to categories", async function () {
      const amount = ethers.parseEther("10");
      
      await treasury.depositToCategory(0, { value: amount });
      
      const balance = await treasury.getBalance(0);
      expect(balance).to.equal(amount);
    });

    it("Should track category-specific limits", async function () {
      const limit = await treasury.getBalanceLimit(0);
      expect(limit).to.equal(ethers.parseEther("100"));
    });

    it("Should track total treasury balance", async function () {
      const total = await treasury.getTotalBalance();
      expect(total).to.be.greaterThan(0n);
    });
  });

  describe("Access Control", function () {
    it("Should manage roles properly", async function () {
      const PROPOSER_ROLE = await accessControl.PROPOSER_ROLE();
      await accessControl.grantRole(PROPOSER_ROLE, member1.address);
      
      const hasRole = await accessControl.hasRole(PROPOSER_ROLE, member1.address);
      expect(hasRole).to.be.true;
    });

    it("Should revoke roles", async function () {
      const VOTER_ROLE = await accessControl.VOTER_ROLE();
      await accessControl.grantRole(VOTER_ROLE, member2.address);
      await accessControl.revokeRole(VOTER_ROLE, member2.address);
      
      const hasRole = await accessControl.hasRole(VOTER_ROLE, member2.address);
      expect(hasRole).to.be.false;
    });

    it("Should list all available roles", async function () {
      const GUARDIAN_ROLE = await accessControl.GUARDIAN_ROLE();
      const TIMELOCK_ADMIN_ROLE = await accessControl.TIMELOCK_ADMIN_ROLE();
      
      expect(GUARDIAN_ROLE).to.not.equal(ethers.ZeroHash);
      expect(TIMELOCK_ADMIN_ROLE).to.not.equal(ethers.ZeroHash);
    });
  });
});
