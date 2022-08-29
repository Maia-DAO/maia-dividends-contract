// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {FlywheelCore, IFlywheelRewards, IFlywheelBooster} from "../../FlywheelCore.sol";

import {FlywheelDynamicRewards, MaiaDynamicRewards, RewardsDepot} from "../../rewards/MaiaDynamicRewards.sol";

import {Auth, Authority} from "../../libraries/Auth.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

contract FlywheelStaticRewardsTest is DSTestPlus {
    using SafeCastLib for uint256;

    MaiaDynamicRewards rewards;

    MockERC20 strategy;
    MockERC20 public rewardToken;
    RewardsDepot public depot;
    Authority public authority;

    function setUp() public {
        rewardToken = new MockERC20("test token", "TKN", 18);

        strategy = new MockERC20("test strategy", "TKN", 18);

        authority = new Authority();

        rewards = new MaiaDynamicRewards(FlywheelCore(address(this)), 604800, authority, address(this));

        depot = new RewardsDepot(rewardToken, address(rewards), authority, address(this));

        rewards.setRewardsDepot(strategy, depot);
    }

    function testGetAccruedRewards() public {
        rewardToken.mint(address(depot), 100 ether);
        require(rewards.getAccruedRewards(strategy, block.timestamp.safeCastTo32()) == 0 ether);
        hevm.warp(60480);

        require(rewards.getAccruedRewards(strategy, (block.timestamp - 60480).safeCastTo32()) == 10 ether);
        require(rewardToken.balanceOf(address(rewards)) == 100 ether);
    }

    function testGetAccruedRewardsAfterEnd() public {
        rewardToken.mint(address(depot), 100 ether);
        require(rewards.getAccruedRewards(strategy, block.timestamp.safeCastTo32()) == 0 ether);
        hevm.warp(604800);

        require(rewards.getAccruedRewards(strategy, (block.timestamp - 604800).safeCastTo32()) == 100 ether);
        require(rewardToken.balanceOf(address(rewards)) == 100 ether);
    }

    function testGetAccruedRewards2Cycles() public {
        rewardToken.mint(address(depot), 100 ether);
        require(rewards.getAccruedRewards(strategy, block.timestamp.safeCastTo32()) == 0 ether);
        hevm.warp(604800);
        rewardToken.mint(address(depot), 100 ether);

        uint32 time = uint32(block.timestamp);
        require(rewards.getAccruedRewards(strategy, time - 604800) == 100 ether);
        require(rewardToken.balanceOf(address(rewards)) == 200 ether);

        hevm.warp(1209600);

        require(rewards.getAccruedRewards(strategy, time) == 100 ether);
        require(rewardToken.balanceOf(address(rewards)) == 200 ether);
    }

    function testGetAccruedRewardsCappedAfterEnd() public {
        rewardToken.mint(address(depot), 100 ether);
        require(rewards.getAccruedRewards(strategy, block.timestamp.safeCastTo32()) == 0 ether);
        hevm.warp(604800);

        uint32 time = uint32(block.timestamp);
        require(rewards.getAccruedRewards(strategy, time - 604800) == 100 ether);
        require(rewardToken.balanceOf(address(rewards)) == 100 ether);

        hevm.warp(1209600);

        require(rewards.getAccruedRewards(strategy, time) == 0 ether);
        require(rewardToken.balanceOf(address(rewards)) == 100 ether);
    }
}
