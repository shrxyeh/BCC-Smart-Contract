// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Crowdfunding is ReentrancyGuard {
    IERC20 public token;
    
    struct Campaign {
        address creator;
        uint256 goal;
        uint256 duration;
        uint256 totalContributed;
        bool isGoalReached;
    }
    
    uint256 public nextCampaignId;
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;

    event CampaignCreated(uint256 campaignId, address creator, uint256 goal, uint256 duration);
    event ContributionMade(uint256 campaignId, address contributor, uint256 amount);
    event ContributionCanceled(uint256 campaignId, address contributor, uint256 amount);
    event FundsWithdrawn(uint256 campaignId, uint256 amount);
    event RefundIssued(uint256 campaignId, address donor, uint256 amount);

    constructor(address _token) {
        require(_token != address(0), "Token address cannot be zero.");
        token = IERC20(_token);
        nextCampaignId = 1;
    }

    function createCampaign(uint256 goal, uint256 duration) external {
        require(goal > 0, "Goal must be greater than 0.");
        require(duration > 0, "Duration must be greater than 0.");
        
        campaigns[nextCampaignId] = Campaign({
            creator: msg.sender,
            goal: goal,
            duration: block.timestamp + duration,
            totalContributed: 0,
            isGoalReached: false
        });
        
        emit CampaignCreated(nextCampaignId, msg.sender, goal, duration);
        nextCampaignId++;
    }

    function contribute(uint256 id, uint256 amount) external nonReentrant {
        require(campaigns[id].duration > 0, "Campaign does not exist.");
        require(block.timestamp < campaigns[id].duration, "Campaign has ended.");
        require(msg.sender != campaigns[id].creator, "Creator cannot contribute.");
        
        token.transferFrom(msg.sender, address(this), amount);
        campaigns[id].totalContributed += amount;
        contributions[id][msg.sender] += amount;

        if (campaigns[id].totalContributed >= campaigns[id].goal) {
            campaigns[id].isGoalReached = true;
        }

        emit ContributionMade(id, msg.sender, amount);
    }

    function cancelContribution(uint256 id) external nonReentrant {
        uint256 contribution = contributions[id][msg.sender];
        require(contribution > 0, "No contributions to cancel.");
        require(block.timestamp < campaigns[id].duration, "Cannot cancel after campaign ends.");
        
        contributions[id][msg.sender] = 0;
        campaigns[id].totalContributed -= contribution;
        token.transfer(msg.sender, contribution);

        emit ContributionCanceled(id, msg.sender, contribution);
    }

    function withdrawFunds(uint256 id) external nonReentrant {
        require(msg.sender == campaigns[id].creator, "Only the creator can withdraw.");
        require(block.timestamp > campaigns[id].duration, "Campaign is still active.");
        require(campaigns[id].isGoalReached, "Goal not reached.");

        uint256 amountToWithdraw = campaigns[id].totalContributed;
        campaigns[id].totalContributed = 0; // Prevent re-entrancy
        token.transfer(msg.sender, amountToWithdraw);

        emit FundsWithdrawn(id, amountToWithdraw);
    }

    function refund(uint256 id) external nonReentrant {
        require(block.timestamp > campaigns[id].duration, "Campaign is still active.");
        require(!campaigns[id].isGoalReached, "Campaign was successful.");
        
        uint256 contribution = contributions[id][msg.sender];
        require(contribution > 0, "No contributions to refund.");

        contributions[id][msg.sender] = 0;
        token.transfer(msg.sender, contribution);

        emit RefundIssued(id, msg.sender, contribution);
    }
}
