// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract StakingRewards{
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    address public owner;

    uint public duration;
    uint public finishAt;
    uint public updateAt;
    uint public rewardRate; //每秒钟奖励的token
    uint public rewardPerTokenStored;//全局rpt记录值 等于rewardRate*duration / 总质押量

    mapping (address=>uint) public userRewardPerTokenPaid; //记录每一位用户的rpt
    mapping (address=>uint) public rewards; //记录每位用户拿到的奖励

    uint public totalSupply; //总质押token
    mapping (address =>uint) public balanceOf; //用户质押的token

    modifier onlyOwner(){
        require(msg.sender==owner,"not owner");
        _;
    }

    // 记录更新全局 rewardPerTokenStored 以及 userRewardPerTokenPaid 在stake和withdraw时更新
    modifier updateReward(address _account){
        rewardPerTokenStored = rewardPerToken();
        updateAt = lastTimeRewardApplicable();

        if (_account != address(0)){
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(address _stakingToken,address _rewardsToken){
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);

    }

    // owner设置奖励时长
    function setRewardsDuration(uint _duration)external onlyOwner {
        // 设置时间时不能持续发放奖励,指当前的reward周期还没有结束
        require(finishAt > block.timestamp,"reward duration not finished");
        duration=_duration;
    }

    // owner 设置奖励时长时去通过duration去计算rewardRate -->确定奖励金额
    function notifyRewardAmount(uint _amount)external onlyOwner updateReward(address(0)){
        // 奖励持续时间还没开始，或者说已经过期了
        if (block.timestamp>finishAt){
            rewardRate = _amount/duration;
        }else {
            uint remainingRewards = rewardRate * (finishAt-block.timestamp); //剩余的奖励
            rewardRate = (remainingRewards + _amount) / duration;
        }
        require(rewardRate > 0,"reward rate = 0");
        require(rewardRate * duration<=rewardsToken.balanceOf(address(this)),"reward amount > balance"); //计算当前合约余额是否足以支付奖励

        // 计算本轮的结束时间
        finishAt = block.timestamp + duration;
        // 更新合约更新时间
        updateAt = block.timestamp;
    }

    // 质押
    function stake(uint _amount)external updateReward(msg.sender) {
        // 保证用户质押的金额大于0
        require(_amount > 0,"amount = 0");
        // stakingToken转移到合约里
        stakingToken.TransferFrom(msg.sender, address(this), _amount);
        // 更新用户的balanceOf,代表用户质押的金额
        balanceOf[msg.sender] += +_amount;
        // 整个合约质押的数量
        totalSupply += _amount;
    }

    // 提款 用户可以提取质押在合约的token
    function withdraw(uint _amount)external updateReward(msg.sender){
        // 保证amount>0
        require(_amount > 0,"amount=0");
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    // 上一次奖励生效的时间
    function lastTimeRewardApplicable()public view {
        return _min(block.timestamp,finishAt);
    }

    // 每个用户能拿到的奖励 
    function rewardPerToken() public view returns (uint){
        if (totalSupply == 0){
            return rewardPerTokenStored;
        }else {
            return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable()-updateAt)) * 1e18 / totalSupply;
        }
    }

    // 用户质押之后查看奖励是多少 金额是多少
    function earned(address _account)public  view returns (uint){
        return (balanceOf[_account] * 
            (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18
         + rewards[_account];
    }

    // 提取奖励
    function getReward()external updateReward(msg.sender){
        // 拿到奖励金额
        uint reward = rewards[msg.sender];
        if (reward > 0){
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender,reward);
        }

    }

    function _min(uint x,uint y) private pure returns (uint){
        return x <= y ? x: y;
    }


}