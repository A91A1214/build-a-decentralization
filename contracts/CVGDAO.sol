// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./CVGToken.sol";
import "./CVGTreasury.sol";

contract CVGDAO is AccessControl, ReentrancyGuard {
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    enum ProposalState { Active, Succeeded, Queued, Executed, Defeated }
    enum ProposalType { HighConviction, Experimental, Operational }
    enum VoteType { Against, For, Abstain }

    struct Proposal {
        address proposer;
        address recipient;
        uint256 amount;
        ProposalType pType;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool queued;
        bool executed;
        mapping(address => bool) voted;
    }

    struct TypeConfig {
        uint256 quorum;
        uint256 threshold;
        uint256 votingPeriod;
        uint256 timelockDelay;
    }

    CVGToken public token;
    CVGTreasury public treasury;

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(ProposalType => TypeConfig) public configs;

    event ProposalCreated(uint256 id, address proposer);
    event VoteCast(address voter, uint256 id, VoteType vote, uint256 weight);
    event ProposalExecuted(uint256 id);

    constructor(
        address tokenAddr,
        address treasuryAddr,
        address admin
    ) {
        token = CVGToken(tokenAddr);
        treasury = CVGTreasury(treasuryAddr);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PROPOSER_ROLE, admin);
        _grantRole(EXECUTOR_ROLE, admin);

        configs[ProposalType.HighConviction] = TypeConfig(20, 60, 7 days, 3 days);
        configs[ProposalType.Experimental] = TypeConfig(10, 50, 3 days, 1 days);
        configs[ProposalType.Operational] = TypeConfig(5, 50, 1 days, 0);
    }

    function propose(
        address recipient,
        uint256 amount,
        ProposalType pType
    ) external onlyRole(PROPOSER_ROLE) returns (uint256) {
        require(token.getVotes(msg.sender) >= 1000e18, "DAO: Insufficient voting power");

        proposalCount++;
        Proposal storage p = proposals[proposalCount];
        p.proposer = msg.sender;
        p.recipient = recipient;
        p.amount = amount;
        p.pType = pType;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + configs[pType].votingPeriod;

        emit ProposalCreated(proposalCount, msg.sender);
        return proposalCount;
    }

    function castVote(uint256 id, VoteType vote) external {
        Proposal storage p = proposals[id];
        require(block.timestamp <= p.endTime, "DAO: Voting ended");
        require(!p.voted[msg.sender], "DAO: Already voted");

        uint256 weight = token.getPastVotes(msg.sender, p.startTime);
        require(weight > 0, "DAO: No voting power");

        p.voted[msg.sender] = true;

        if (vote == VoteType.For) p.forVotes += weight;
        else if (vote == VoteType.Against) p.againstVotes += weight;
        else p.abstainVotes += weight;

        emit VoteCast(msg.sender, id, vote, weight);
    }

    function execute(uint256 id) external onlyRole(EXECUTOR_ROLE) nonReentrant {
        Proposal storage p = proposals[id];
        require(!p.executed, "DAO: Already executed");
        require(block.timestamp > p.endTime + configs[p.pType].timelockDelay, "DAO: Timelocked");

        p.executed = true;

        treasury.withdraw(
            payable(p.recipient),
            p.amount,
            CVGTreasury.FundCategory(uint8(p.pType))
        );

        emit ProposalExecuted(id);
    }
}
