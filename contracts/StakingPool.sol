// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";
contract StakingPool is ReentrancyGuard {
    IERC20 public stakingToken;
    IERC20 public rewardToken;

    uint256 public constant REWARD_PER_BLOCK = 100;

    uint256 private totalSupply;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public virtualRewardDebtPerToken;

    uint256 private accumulatedRewardPerToken;
    uint256 private lastRewardUpdateBlock;

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    // Modifiers

    modifier updateReward(address user) {
        accumulatedRewardPerToken = getAccumulatedRewardPerToken();
        lastRewardUpdateBlock = block.number;
        rewards[user] = earned(user);
        virtualRewardDebtPerToken[user] = accumulatedRewardPerToken;
        _;
    }

    modifier moreThanZero(uint256 amount) {
        require(amount > 0, "Amount must be more than zero");
        _;
    }

    // Public functions

    function getAccumulatedRewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return accumulatedRewardPerToken;
        }

        return accumulatedRewardPerToken
            + (block.number - lastRewardUpdateBlock) * REWARD_PER_BLOCK
                * (rewardToken.balanceOf(address(this)) * 1e18 / totalSupply);
    }

    function earned(address user) public view returns (uint256) {
        return stakedBalance[user] * (getAccumulatedRewardPerToken() - virtualRewardDebtPerToken[user]) / 1e18
            + rewards[user];
    }

    function stake(uint256 amount) external updateReward(msg.sender) nonReentrant moreThanZero(amount) {
        require(amount > 0, "Cannot stake 0");
        totalSupply += amount;
        stakedBalance[msg.sender] += amount;
        stakingToken.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) nonReentrant moreThanZero(amount) {
        require(amount > 0, "Cannot withdraw 0");
        totalSupply -= amount;
        stakedBalance[msg.sender] -= amount;
        bool success = stakingToken.transfer(msg.sender, amount);
        if (!success) {
            revert("Failed to withdraw");
        }
    }

    function claimReward() external updateReward(msg.sender) nonReentrant {
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        bool success = rewardToken.transfer(msg.sender, reward);
        if (!success) {
            revert("Failed to claim reward");
        }
    }

    // Getter functions

    function totalStakedSupply() public view returns (uint256) {
        return totalSupply;
    }

    function getStakedBalance(address user) public view returns (uint256) {
        return stakedBalance[user];
    }
}
