import { ethers } from "hardhat";

async function main() {
  console.log("Deploying CryptoVentures DAO Governance System...\n");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH\n");

  // Deploy GovernanceToken
  console.log("1. Deploying GovernanceToken...");
  const GovernanceTokenFactory = await ethers.getContractFactory("GovernanceToken");
  const governanceToken = await GovernanceTokenFactory.deploy();
  await governanceToken.waitForDeployment();
  const governanceTokenAddr = await governanceToken.getAddress();
  console.log("   GovernanceToken deployed to:", governanceTokenAddr, "\n");

  // Deploy VotingDelegation
  console.log("2. Deploying VotingDelegation...");
  const VotingDelegationFactory = await ethers.getContractFactory("VotingDelegation");
  const votingDelegation = await VotingDelegationFactory.deploy(governanceTokenAddr);
  await votingDelegation.waitForDeployment();
  const votingDelegationAddr = await votingDelegation.getAddress();
  console.log("   VotingDelegation deployed to:", votingDelegationAddr, "\n");

  // Deploy DAOTreasury
  console.log("3. Deploying DAOTreasury...");
  const TreasuryFactory = await ethers.getContractFactory("DAOTreasury");
  const treasury = await TreasuryFactory.deploy(
    ethers.parseEther("100"),    // High conviction limit
    ethers.parseEther("50"),     // Experimental limit
    ethers.parseEther("10")      // Operational limit
  );
  await treasury.waitForDeployment();
  const treasuryAddr = await treasury.getAddress();
  console.log("   DAOTreasury deployed to:", treasuryAddr, "\n");

  // Deploy DAOAccessControl
  console.log("4. Deploying DAOAccessControl...");
  const AccessControlFactory = await ethers.getContractFactory("DAOAccessControl");
  const accessControl = await AccessControlFactory.deploy();
  await accessControl.waitForDeployment();
  const accessControlAddr = await accessControl.getAddress();
  console.log("   DAOAccessControl deployed to:", accessControlAddr, "\n");

  // Deploy DAOGovernance
  console.log("5. Deploying DAOGovernance...");
  const GovernanceFactory = await ethers.getContractFactory("DAOGovernance");
  const governance = await GovernanceFactory.deploy(
    governanceTokenAddr,
    votingDelegationAddr,
    treasuryAddr,
    accessControlAddr
  );
  await governance.waitForDeployment();
  const governanceAddr = await governance.getAddress();
  console.log("   DAOGovernance deployed to:", governanceAddr, "\n");

  // Setup roles
  console.log("6. Setting up roles and permissions...");
  
  // Grant governance contract as executor
  await accessControl.grantRole(
    await accessControl.EXECUTOR_ROLE(),
    governanceAddr
  );
  
  // Grant deployer as guardian and admin
  await accessControl.grantRole(
    await accessControl.GUARDIAN_ROLE(),
    deployer.address
  );
  
  await accessControl.grantRole(
    await accessControl.TIMELOCK_ADMIN_ROLE(),
    deployer.address
  );

  console.log("   Roles granted\n");

  // Transfer treasury ownership to governance
  console.log("7. Transferring treasury ownership to governance...");
  await treasury.transferOwnership(governanceAddr);
  console.log("   Ownership transferred\n");

  // Summary
  console.log("=".repeat(60));
  console.log("DEPLOYMENT SUMMARY");
  console.log("=".repeat(60));
  console.log("GovernanceToken:    ", governanceTokenAddr);
  console.log("VotingDelegation:   ", votingDelegationAddr);
  console.log("DAOTreasury:        ", treasuryAddr);
  console.log("DAOAccessControl:   ", accessControlAddr);
  console.log("DAOGovernance:      ", governanceAddr);
  console.log("=".repeat(60));

  // Save deployment info
  const deploymentInfo = {
    network: "localhost",
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      governanceToken: governanceTokenAddr,
      votingDelegation: votingDelegationAddr,
      treasury: treasuryAddr,
      accessControl: accessControlAddr,
      governance: governanceAddr,
    },
  };

  console.log("\nDeployment completed successfully!\n");
  console.log("Configuration for environment:");
  console.log("- GOVERNANCE_TOKEN_ADDRESS:", governanceTokenAddr);
  console.log("- VOTING_DELEGATION_ADDRESS:", votingDelegationAddr);
  console.log("- TREASURY_ADDRESS:", treasuryAddr);
  console.log("- ACCESS_CONTROL_ADDRESS:", accessControlAddr);
  console.log("- GOVERNANCE_ADDRESS:", governanceAddr);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
