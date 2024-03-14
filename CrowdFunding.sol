// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Crowdfunding {
    ERC20 private token;

    struct Campaign {
        address creator;
        uint256 goal;
        uint256 duration;
        uint256 startAt;
        uint256 totalFunds;
        bool fundsCollected;
    }

    uint256 private nextCampaignId = 1;
    mapping(uint256 => Campaign) private campaigns;
    mapping(uint256 => mapping(address => uint256)) private contributions;

    event CampaignCreated(uint256 indexed campaignId, address creator, uint256 goal, uint256 duration);
    event ContributionMade(uint256 indexed campaignId, address donor, uint256 amount);
    event ContributionCanceled(uint256 indexed campaignId, address donor, uint256 amount);
    event FundsWithdrawn(uint256 indexed campaignId, uint256 totalFunds);
    event RefundIssued(uint256 indexed campaignId, address donor, uint256 amount);

    constructor(address _token) {
        require(_token != address(0), "Token address cannot be the zero address");
        token = ERC20(_token);
    }

    function createCampaign(uint256 goal, uint256 duration) external {
        require(goal > 0, "Goal must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");

        campaigns[nextCampaignId] = Campaign({
            creator: msg.sender,
            goal: goal,
            duration: duration,
            startAt: block.timestamp,
            totalFunds: 0,
            fundsCollected: false
        });

        emit CampaignCreated(nextCampaignId, msg.sender, goal, duration);
        nextCampaignId++;
    }

    function contribute(uint256 campaignId, uint256 amount) external {
        Campaign storage campaign = campaigns[campaignId];
        require(campaign.startAt != 0, "Campaign does not exist");
        require(block.timestamp < campaign.startAt + campaign.duration, "Campaign has ended");
        require(msg.sender != campaign.creator, "Creator cannot contribute to their own campaign");

        token.transferFrom(msg.sender, address(this), amount);
        contributions[campaignId][msg.sender] += amount;
        campaign.totalFunds += amount;

        emit ContributionMade(campaignId, msg.sender, amount);
    }

    function cancelContribution(uint256 campaignId) external {
        uint256 amount = contributions[campaignId][msg.sender];
        require(amount > 0, "No contribution to cancel");

        contributions[campaignId][msg.sender] = 0;
        campaigns[campaignId].totalFunds -= amount;

        token.transfer(msg.sender, amount);
        emit ContributionCanceled(campaignId, msg.sender, amount);
    }

    function withdrawFunds(uint256 campaignId) external {
        Campaign storage campaign = campaigns[campaignId];
        require(msg.sender == campaign.creator, "Only the creator can withdraw");
        require(block.timestamp > campaign.startAt + campaign.duration, "Campaign still ongoing");
        require(campaign.totalFunds >= campaign.goal, "Funding goal not reached");
        require(!campaign.fundsCollected, "Funds already withdrawn");

        campaign.fundsCollected = true;
        token.transfer(campaign.creator, campaign.totalFunds);

        emit FundsWithdrawn(campaignId, campaign.totalFunds);
    }

    function refund(uint256 campaignId) external {
        Campaign storage campaign = campaigns[campaignId];
        require(block.timestamp > campaign.startAt + campaign.duration, "Campaign still ongoing");
        require(campaign.totalFunds < campaign.goal, "Funding goal reached");
        
        uint256 amount = contributions[campaignId][msg.sender];
        require(amount > 0, "No contributions to refund");

        contributions[campaignId][msg.sender] = 0;
        token.transfer(msg.sender, amount);

        emit RefundIssued(campaignId, msg.sender, amount);
    }
}
