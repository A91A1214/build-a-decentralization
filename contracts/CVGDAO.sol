// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./CVGToken.sol";
import "./CVGTreasury.sol";
import "./CVGTimelock.sol";

contract CVGDAO is AccessControl, ReentrancyGuard {
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    enum ProposalState { Pending, Active, Succeeded, Queued, Executed, Defeated, Canceled }
    enum ProposalType { HighConviction, Experimental, Operational }
    enum VoteType { Against, For, Abstain }

    struct Proposal {
        uint256 id;
        address proposer;
        address recipient;
        uint256 amount;
        string description;
        ProposalType pType;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool queued;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
    }

    struct TypeSettings {
        uint256 quorumLimit;
        uint256 thresholdLimit;
        uint256 votingPeriod;
        uint256 timelockDelay;
    }

    CVGToken public token;
    CVGTreasury public treasury;
    CVGTimelock public timelock;

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(ProposalType => TypeSettings) public typeSettings;

    event ProposalCreated(uint256 indexed id, address indexed proposer, ProposalType pType, string description);
    event VoteCast(address indexed voter, uint256 indexed proposalId, VoteType voteType, uint256 weight);
    event ProposalQueued(uint256 indexed id, uint256 eta);
    event ProposalExecuted(uint256 indexed id);
    event ProposalCanceled(uint256 indexed id);

    constructor(
        address _token,
        address payable _treasury,
        address payable _timelock,
        address admin
    ) {
        token = CVGToken(_token);
        treasury = CVGTreasury(_treasury);
        timelock = CVGTimelock(_timelock);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PROPOSER_ROLE, admin);
        _grantRole(GUARDIAN_ROLE, admin);
        _grantRole(EXECUTOR_ROLE, admin);

        typeSettings[ProposalType.HighConviction] = TypeSettings(20, 60, 7 days, 3 days);
        typeSettings[ProposalType.Experimental] = TypeSettings(10, 50, 3 days, 1 days);
        typeSettings[ProposalType.Operational] = TypeSettings(5, 50, 1 days, 0);
    }

    function propose(address recipient, uint256 amount, string memory description, ProposalType pType) external onlyRole(PROPOSER_ROLE) returns (uint256) {
        require(token.getVotes(msg.sender) >= 1000 * 10**18, "DAO: Insufficient stake");
        proposalCount++;
        Proposal storage p = proposals[proposalCount];
        p.id = proposalCount;
        p.proposer = msg.sender;
        p.recipient = recipient;
        p.amount = amount;
        p.description = description;
        p.pType = pType;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + typeSettings[pType].votingPeriod;
        emit ProposalCreated(proposalCount, msg.sender, pType, description);
        return proposalCount;
    }

    function castVote(uint256 proposalId, VoteType voteType) external {
        Proposal storage p = proposals[proposalId];
        require(state(proposalId) == ProposalState.Active, "DAO: Not active");
        require(!p.hasVoted[msg.sender], "DAO: Voted");
        uint256 weight = token.getPastVotes(msg.sender, p.startTime);
        require(weight > 0, "DAO: No power");
        p.hasVoted[msg.sender] = true;
        if (voteType == VoteType.For) p.forVotes += weight;
        else if (voteType == VoteType.Against) p.againstVotes += weight;
        else p.abstainVotes += weight;
        emit VoteCast(msg.sender, proposalId, voteType, weight);
    }

    function queue(uint256 proposalId) external {
        require(state(proposalId) == ProposalState.Succeeded, "DAO: Not succeeded");
        proposals[proposalId].queued = true;
        emit ProposalQueued(proposalId, block.timestamp + typeSettings[proposals[proposalId].pType].timelockDelay);
    }

    function execute(uint256 proposalId) external onlyRole(EXECUTOR_ROLE) nonReentrant {
        require(state(proposalId) == ProposalState.Queued, "DAO: Not queued");
        Proposal storage p = proposals[proposalId];
        require(block.timestamp >= p.endTime + typeSettings[p.pType].timelockDelay, "DAO: Timelock");
        p.executed = true;
        CVGTreasury.FundCategory cat = (p.pType == ProposalType.HighConviction) ? CVGTreasury.FundCategory.HighConviction : (p.pType == ProposalType.Experimental ? CVGTreasury.FundCategory.Experimental : CVGTreasury.FundCategory.Operational);
        treasury.withdraw(payable(p.recipient), p.amount, cat);
        emit ProposalExecuted(proposalId);
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage p = proposals[proposalId];
        if (p.canceled) return ProposalState.Canceled;
        if (p.executed) return ProposalState.Executed;
        if (p.queued) return ProposalState.Queued;
        if (block.timestamp <= p.endTime) return ProposalState.Active;
        uint256 total = p.forVotes + p.againstVotes + p.abstainVotes;
        uint256 supply = token.getPastTotalSupply(p.startTime);
        if ((total * 100) / supply >= typeSettings[p.pType].quorumLimit && (p.forVotes * 100) / (p.forVotes + p.againstVotes + 1) >= typeSettings[p.pType].thresholdLimit) return ProposalState.Succeeded;
        return ProposalState.Defeated;
    }
}
