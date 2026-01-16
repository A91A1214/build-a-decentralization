import { expect } from "chai";
import pkg from "hardhat";
const { ethers } = pkg;
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("CryptoVentures DAO", function () {
    let token, treasury, timelock, dao;
    let owner, proposer, voter1, voter2, recipient;
    const ONE_ETHER = ethers.parseUnits("1", 18);

    beforeEach(async function () {
        [owner, proposer, voter1, voter2, recipient] = await ethers.getSigners();

        // Deploy Token
        const CVGToken = await ethers.getContractFactory("CVGToken");
        token = await CVGToken.deploy(owner.address);

        // Deploy Treasury
        const CVGTreasury = await ethers.getContractFactory("CVGTreasury");
        treasury = await CVGTreasury.deploy(owner.address);

        // Deploy Timelock
        const CVGTimelock = await ethers.getContractFactory("CVGTimelock");
        timelock = await CVGTimelock.deploy(
            3600, // 1 hour min delay
            [owner.address], // temporary proposers
            [owner.address], // temporary executors
            owner.address
        );

        // Deploy DAO
        const CVGDAO = await ethers.getContractFactory("CVGDAO");
        dao = await CVGDAO.deploy(
            await token.getAddress(),
            await treasury.getAddress(),
            await timelock.getAddress(),
            owner.address
        );

        // Setup Roles
        const TREASURY_EXECUTOR_ROLE = await treasury.EXECUTOR_ROLE();
        const DAO_EXECUTOR_ROLE = await dao.EXECUTOR_ROLE();
        const PROPOSER_ROLE = await dao.PROPOSER_ROLE();

        // DAO contract needs role to withdraw from treasury
        await treasury.grantRole(TREASURY_EXECUTOR_ROLE, await dao.getAddress());
        // Owner needs role to trigger execution in DAO
        await dao.grantRole(DAO_EXECUTOR_ROLE, owner.address);
        await dao.grantRole(PROPOSER_ROLE, proposer.address);

        // Transfer ETH to Treasury
        await owner.sendTransaction({
            to: await treasury.getAddress(),
            value: ethers.parseUnits("100", 18),
        });

        // Staking for votes
        await token.connect(proposer).stake({ value: ONE_ETHER }); // 1000 CVG
        await token.connect(voter1).stake({ value: ethers.parseUnits("10", 18) }); // 10000 CVG
        await token.connect(voter2).stake({ value: ethers.parseUnits("5", 18) }); // 5000 CVG

        // Move time forward to ensure snapshots are taken
        await time.increase(1);
    });

    it("Should allow staking and receive voting power", async function () {
        expect(await token.balanceOf(voter1.address)).to.equal(ethers.parseUnits("10000", 18));
        expect(await token.getVotes(voter1.address)).to.equal(ethers.parseUnits("10000", 18));
    });

    it("Should create a proposal and process it to execution", async function () {
        // Propose
        const description = "Test Investment";
        const amount = ethers.parseUnits("1", 18);

        await dao.connect(proposer).propose(
            recipient.address,
            amount,
            description,
            2 // Operational (Type 2 has 1 day period, 0 delay)
        );

        const proposalId = await dao.proposalCount();

        // Move to active voting
        await time.increase(1);

        // Vote
        await dao.connect(voter1).castVote(proposalId, 1); // For
        await dao.connect(voter2).castVote(proposalId, 1); // For

        // Move past voting period
        await time.increase(86400 + 1);

        // Check state (Succeeded)
        // ProposalState: Pending(0), Active(1), Succeeded(2), Queued(3), Executed(4), Defeated(5), Canceled(6)
        expect(await dao.state(proposalId)).to.equal(2n); // Succeeded

        // Queue
        await dao.queue(proposalId);
        expect(await dao.state(proposalId)).to.equal(3n); // Queued

        // Execute
        const initialBalance = await ethers.provider.getBalance(recipient.address);
        await dao.connect(owner).execute(proposalId);
        const finalBalance = await ethers.provider.getBalance(recipient.address);

        expect(finalBalance - initialBalance).to.equal(amount);
        expect(await dao.state(proposalId)).to.equal(4n); // Executed
    });

    it("Should respect quorum requirements", async function () {
        // Propose High Conviction (needs 20% quorum)
        await dao.connect(proposer).propose(
            recipient.address,
            ethers.parseUnits("50", 18),
            "Big Bet",
            0 // HighConviction
        );

        const proposalId = await dao.proposalCount();
        await time.increase(1);

        await time.increase(7 * 86400 + 1); // End of 7 days voting
        expect(await dao.state(proposalId)).to.equal(5n); // Defeated
    });
});
