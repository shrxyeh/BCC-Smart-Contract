// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CrowdfundToken is ERC20, Ownable {
    uint256 private immutable tokenPriceUSD;

    struct Campaign {
        address creator;
        uint256 goal;
        uint256 start;
        uint256 duration;
        uint256 totalRaised;
        bool withdrawn;
    }

    uint256 private nextId = 1;
    mapping(uint256 => Campaign) private campaigns;
    mapping(uint256 => mapping(address => uint256)) private contribs;

    constructor(string memory name, string memory symbol, uint256 priceUSD)
        ERC20(name, symbol)
        Ownable()
    {
        tokenPriceUSD = priceUSD;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function price() external view returns (uint256) {
        return tokenPriceUSD;
    }

    function newCampaign(uint256 goal, uint256 time) external {
        campaigns[nextId] = Campaign({
            creator: msg.sender,
            goal: goal,
            start: block.timestamp,
            duration: time,
            totalRaised: 0,
            withdrawn: false
        });
        nextId++;
    }

    function addFunds(uint256 id, uint256 amount) external {
        require(campaigns[id].creator != address(0), "Invalid campaign");
        require(block.timestamp <= campaigns[id].start + campaigns[id].duration, "Ended");

        _transfer(msg.sender, address(this), amount);
        contribs[id][msg.sender] += amount;
        campaigns[id].totalRaised += amount;
    }

    function cancelFunds(uint256 id) external {
        uint256 amount = contribs[id][msg.sender];
        require(amount > 0, "No funds");

        contribs[id][msg.sender] = 0;
        campaigns[id].totalRaised -= amount;
        _transfer(address(this), msg.sender, amount);
    }

    function withdraw(uint256 id) external {
        Campaign storage c = campaigns[id];
        require(msg.sender == c.creator, "Unauthorized");
        require(block.timestamp > c.start + c.duration, "Ongoing");
        require(c.totalRaised >= c.goal, "Goal not met");
        require(!c.withdrawn, "Already withdrawn");

        c.withdrawn = true;
        _transfer(address(this), msg.sender, c.totalRaised);
    }

    function refund(uint256 id) external {
        require(block.timestamp > campaigns[id].start + campaigns[id].duration, "Ongoing");
        require(campaigns[id].totalRaised < campaigns[id].goal, "Goal met");
        
        uint256 amount = contribs[id][msg.sender];
        require(amount > 0, "No funds");

        contribs[id][msg.sender] = 0;
        _transfer(address(this), msg.sender, amount);
    }
}
