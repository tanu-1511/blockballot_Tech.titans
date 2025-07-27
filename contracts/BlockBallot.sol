// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./5_VoteReceiptNFT.sol";

contract BlockBallot {
    struct Candidate {
        string name;
        string manifestoIPFS;
        uint voteCount;
        address wallet;
        uint totalFundsReceived;
    }

    address public admin;
    uint public startTime;
    uint public endTime;
    uint public totalVoters;
    uint public totalVotes;

    VoteReceiptNFT public nft;

    mapping(address => bool) public hasVoted;
    mapping(address => bool) public isEligibleVoter;
    Candidate[] public candidates;

    event Voted(address voter, uint candidateIndex);
    event FundsReceived(address candidate, uint amount);
    event BribeDetected(address voter, uint amount);
    event ActionSuccess(string message);


    constructor(address _nftAddress, uint _startTime) {
        admin = msg.sender;
        startTime = _startTime;
        endTime = _startTime + 3 hours;
        nft = VoteReceiptNFT(_nftAddress);
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier duringVoting() {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Voting closed");
        _;
    }

    function addCandidate(string memory _name, string memory _manifestoIPFS, address _wallet) public onlyAdmin {
        candidates.push(Candidate(_name, _manifestoIPFS, 0, _wallet, 0));
        emit ActionSuccess("Candidate added successfully");
    }

    function registerVoter(address _voter) public onlyAdmin {
        require(!isEligibleVoter[_voter], "Already registered");
        isEligibleVoter[_voter] = true;
        totalVoters++;
        emit ActionSuccess("Voter registered successfully");
    }

    function vote(uint candidateIndex, string memory gamifiedUri) public duringVoting returns (uint,uint) {
        require(isEligibleVoter[msg.sender], "Not eligible");
        require(!hasVoted[msg.sender], "Already voted");
        require(candidateIndex < candidates.length, "Invalid candidate");

        candidates[candidateIndex].voteCount += 1;
        hasVoted[msg.sender] = true;
        totalVotes++;

        
        nft.mintReceipt(msg.sender, gamifiedUri);

        emit Voted(msg.sender, candidateIndex);
        emit ActionSuccess("Vote successfully recorded");
        return (candidateIndex, candidates[candidateIndex].voteCount);
    }

    // --- Fund Tracking ---
    receive() external payable {
        for (uint i = 0; i < candidates.length; i++) {
            if (msg.sender == candidates[i].wallet) {
                candidates[i].totalFundsReceived += msg.value;
                emit FundsReceived(msg.sender, msg.value);
            }
        }
        emit ActionSuccess("Funds received successfully");
    }

    // --- Statistics & Analysis ---

    function calculateTransparencyScore(uint index) public view returns (uint) {
        Candidate memory c = candidates[index];
        if (c.voteCount == 0) return 0;
        return (c.totalFundsReceived * 1000) / c.voteCount;
    }

    function detectBribe(uint candidateIndex, uint suspiciousThreshold) public view returns (bool) {
        uint score = calculateTransparencyScore(candidateIndex);
        return score > suspiciousThreshold;
    }

    function getTrustIndex(uint candidateIndex) public view returns (uint) {
        uint score = calculateTransparencyScore(candidateIndex);
        if (score > 1000) return 100;
        if (score > 500) return 80;
        return 50;
    }

    function getVoterTurnoutPercentage() public view returns (uint) {
        if (totalVoters == 0) return 0;
        return (totalVotes * 100) / totalVoters;
    }

    function getCandidateLeaderboard() public view returns (string[] memory names, uint[] memory votes) {
        uint len = candidates.length;
        names = new string[](len);
        votes = new uint[](len);

        for (uint i = 0; i < len; i++) {
            names[i] = candidates[i].name;
            votes[i] = candidates[i].voteCount;
        }
    }

    function isVotingOpen() public view returns (bool) {
        return block.timestamp >= startTime && block.timestamp <= endTime;
    }

    function withdraw() public onlyAdmin {
        payable(admin).transfer(address(this).balance);
    }

    // --- Utility Functions ---

    function getCandidateCount() public view returns (uint) {
        return candidates.length;
    }

    function getCandidate(uint index) public view returns (string memory, string memory, uint, address, uint) {
        Candidate memory c = candidates[index];
        return (c.name, c.manifestoIPFS, c.voteCount, c.wallet, c.totalFundsReceived);
    }
}

