import pkg from "hardhat";
const { ethers } = pkg;

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // 1. Deploy CVGToken
    const CVGToken = await ethers.getContractFactory("CVGToken");
    const token = await CVGToken.deploy(deployer.address);
    await token.waitForDeployment();
    console.log("CVGToken deployed to:", await token.getAddress());

    // 2. Deploy CVGTreasury
    const CVGTreasury = await ethers.getContractFactory("CVGTreasury");
    const treasury = await CVGTreasury.deploy(deployer.address);
    await treasury.waitForDeployment();
    console.log("CVGTreasury deployed to:", await treasury.getAddress());

    // 3. Deploy CVGTimelock
    // minDelay, proposers, executors, admin
    const CVGTimelock = await ethers.getContractFactory("CVGTimelock");
    const timelock = await CVGTimelock.deploy(
        3600, // 1 hour min delay
        [], // Proposers set later
        [], // Executors set later
        deployer.address
    );
    await timelock.waitForDeployment();
    console.log("CVGTimelock deployed to:", await timelock.getAddress());

    // 4. Deploy CVGDAO
    const CVGDAO = await ethers.getContractFactory("CVGDAO");
    const dao = await CVGDAO.deploy(
        await token.getAddress(),
        await treasury.getAddress(),
        await timelock.getAddress(),
        deployer.address
    );
    await dao.waitForDeployment();
    console.log("CVGDAO deployed to:", await dao.getAddress());

    // 5. Setup Roles
    console.log("Setting up roles...");

    const TREASURY_EXECUTOR_ROLE = await treasury.EXECUTOR_ROLE();
    await treasury.grantRole(TREASURY_EXECUTOR_ROLE, await dao.getAddress());

    const DAO_EXECUTOR_ROLE = await dao.EXECUTOR_ROLE();
    await dao.grantRole(DAO_EXECUTOR_ROLE, deployer.address);

    const PROPOSER_ROLE = await dao.PROPOSER_ROLE();
    await dao.grantRole(PROPOSER_ROLE, deployer.address);

    console.log("Deployment and setup complete!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
