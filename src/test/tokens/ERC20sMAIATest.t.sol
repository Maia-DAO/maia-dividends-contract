// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockBooster} from "../mocks/MockBooster.sol";
import {MockRewards} from "../mocks/MockRewards.sol";
import {FlywheelCore, IFlywheelRewards, IFlywheelBooster} from "../../FlywheelCore.sol";

import {FlywheelDynamicRewards, MaiaDynamicRewards, RewardsDepot} from "../../rewards/MaiaDynamicRewards.sol";

import {Auth, Authority} from "../../libraries/Auth.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

import {ERC20sMaia} from "../../token/ERC20sMAIA.sol";

contract ERC20sMaiaTest is DSTestPlus {
    using SafeCastLib for uint256;

    ERC20sMaia sMaia;

    FlywheelCore core;
    MockRewards rewards;

    MockERC20 maia;
    MockERC20 public rewardToken;
    RewardsDepot public depot;
    Authority public authority;

    address constant user = address(0xDEAD);
    address constant user2 = address(0xBEEF);

    function setUp() public {
        rewardToken = new MockERC20("test token", "TKN", 18);

        maia = new MockERC20("Maia", "MAIA", 18);

        authority = new Authority();

        sMaia = new ERC20sMaia(authority, address(this), maia);

        core = new FlywheelCore(
            rewardToken,
            MockRewards(address(0)),
            IFlywheelBooster(address(0)),
            address(this),
            authority
        );

        rewards = new MockRewards(core);

        core.setFlywheelRewards(rewards);
    }

    function testAddFlywheelCore(FlywheelCore flywheel) public {
        uint256 len = sMaia.getRewardsLenght();

        sMaia.addFlywheelCore(flywheel);
        require(sMaia.getRewardsLenght() == len + 1);
        require(sMaia.isFlywheel(flywheel) == true);
        require(sMaia.isFlywheelActive(flywheel));
        require(sMaia.allFlywheels(len) == flywheel);
    }

    function testAddFlywheelCoreFail(FlywheelCore flywheel) public {
        uint256 len = sMaia.getRewardsLenght();

        hevm.prank(address(1));
        hevm.expectRevert(bytes("UNAUTHORIZED"));
        sMaia.addFlywheelCore(flywheel);

        require(sMaia.getRewardsLenght() == len);
        require(sMaia.isFlywheel(flywheel) == false);
        require(!sMaia.isFlywheelActive(flywheel));

        testAddFlywheelCore(flywheel);

        hevm.expectRevert(bytes("Flywheel already exists"));
        sMaia.addFlywheelCore(flywheel);
    }

    function testAddFlywheelCoreFailMax() public {
        uint256 i = 0;
        for (; i < 20; ) {
            testAddFlywheelCore(FlywheelCore(address(uint160(i))));
            unchecked {
                i++;   
            }
        }
        require(sMaia.getRewardsLenght() == 20);

        hevm.expectRevert(bytes("Max Flywheels"));
        sMaia.addFlywheelCore(core);

        require(sMaia.isFlywheel(core) == false);
        require(!sMaia.isFlywheelActive(core));
        require(sMaia.getRewardsLenght() == 20);

    }

    function testToggleFlywheel(FlywheelCore flywheel) public {
        testAddFlywheelCore(flywheel);

        sMaia.toggleFlywheel(flywheel);
        require(!sMaia.isFlywheelActive(flywheel));
    }

    function testToggleFlywheelFail(FlywheelCore flywheel) public {
        hevm.expectRevert(bytes("Flywheel doesn't exist"));
        sMaia.toggleFlywheel(flywheel);

        testAddFlywheelCore(flywheel);

        hevm.prank(address(1));
        hevm.expectRevert(bytes("UNAUTHORIZED"));
        sMaia.toggleFlywheel(flywheel);

        require(sMaia.isFlywheelActive(flywheel));
    }

    // function testStake() public {
        // uint256 stakeAmount = 1 ether;
    function testStake(address to, uint256 stakeAmount) public {
        uint256 maiaBal = maia.balanceOf(address(sMaia));
        uint256 sMaiaBal = sMaia.balanceOf(to);
        
        maia.mint(to, stakeAmount);

        hevm.prank(to);
        maia.approve(address(sMaia), stakeAmount);
        hevm.prank(to);
        sMaia.stake(to, stakeAmount);

        require(maia.balanceOf(address(sMaia)) - maiaBal == stakeAmount);
        require(sMaia.balanceOf(to) - sMaiaBal == stakeAmount);
    }

    function testUnstake(address from, uint256 unstakeAmount) public {
        uint256 maiaBal = maia.balanceOf(address(from));
        uint256 sMaiaBal = sMaia.balanceOf(address(from));

        testStake(from, unstakeAmount);

        hevm.prank(from);
        sMaia.unstake(from, unstakeAmount);

        require(maia.balanceOf(address(from)) - maiaBal == unstakeAmount);
        require(sMaia.balanceOf(address(from)) - sMaiaBal == 0);
    }

    function testAccrue(
        uint128 userBalance1,
        uint128 userBalance2,
        uint128 rewardAmount
    ) public {
        hevm.assume(userBalance1 != 0 && userBalance2 != 0 && rewardAmount != 0);

        testStake(user, userBalance1);
        testStake(user2, userBalance2);

        rewardToken.mint(address(rewards), rewardAmount);
        rewards.setRewardsAmount(sMaia, rewardAmount);

        core.addStrategyForRewards(sMaia);

        uint256 accrued = core.accrue(sMaia, user);

        (uint224 index, ) = core.strategyState(sMaia);

        uint256 diff = (rewardAmount * core.ONE()) / (uint256(userBalance1) + userBalance2);

        require(index == core.ONE() + diff);
        require(core.userIndex(sMaia, user) == index);
        require(core.rewardsAccrued(user) == (diff * userBalance1) / core.ONE());
        require(accrued == (diff * userBalance1) / core.ONE());
        require(core.rewardsAccrued(user2) == 0 ether);

        require(rewardToken.balanceOf(address(rewards)) == rewardAmount);
    }

    function testAccrueTwoUsers(
        uint128 userBalance1,
        uint128 userBalance2,
        uint128 rewardAmount
    ) public {
        hevm.assume(userBalance1 != 0 && userBalance2 != 0 && rewardAmount != 0);

        testStake(user, userBalance1);
        testStake(user2, userBalance2);

        rewardToken.mint(address(rewards), rewardAmount);
        rewards.setRewardsAmount(sMaia, rewardAmount);

        core.addStrategyForRewards(sMaia);

        (uint256 accrued1, uint256 accrued2) = core.accrue(sMaia, user, user2);

        (uint224 index, ) = core.strategyState(sMaia);

        uint256 diff = (rewardAmount * core.ONE()) / (uint256(userBalance1) + userBalance2);

        require(index == core.ONE() + diff);
        require(core.userIndex(sMaia, user) == index);
        require(core.userIndex(sMaia, user2) == index);
        require(core.rewardsAccrued(user) == (diff * userBalance1) / core.ONE());
        require(core.rewardsAccrued(user2) == (diff * userBalance2) / core.ONE());
        require(accrued1 == (diff * userBalance1) / core.ONE());
        require(accrued2 == (diff * userBalance2) / core.ONE());

        require(rewardToken.balanceOf(address(rewards)) == rewardAmount);
    }

    function testAccrueBeforeAddStrategy(uint128 mintAmount, uint128 rewardAmount) public {
        testStake(user, mintAmount);

        rewardToken.mint(address(rewards), rewardAmount);
        rewards.setRewardsAmount(sMaia, rewardAmount);

        require(core.accrue(sMaia, user) == 0);
    }

    function testAccrueTwoUsersBeforeAddStrategy() public {
        testStake(user, 1 ether);
        testStake(user2, 3 ether);

        rewardToken.mint(address(rewards), 10 ether);
        rewards.setRewardsAmount(sMaia, 10 ether);

        (uint256 accrued1, uint256 accrued2) = core.accrue(sMaia, user, user2);

        require(accrued1 == 0);
        require(accrued2 == 0);
    }

    function testAccrueTwoUsersSeparately() public {
        testStake(user, 1 ether);
        testStake(user2, 3 ether);

        rewardToken.mint(address(rewards), 10 ether);
        rewards.setRewardsAmount(sMaia, 10 ether);

        core.addStrategyForRewards(sMaia);

        uint256 accrued = core.accrue(sMaia, user);

        rewards.setRewardsAmount(sMaia, 0);

        uint256 accrued2 = core.accrue(sMaia, user2);

        (uint224 index, ) = core.strategyState(sMaia);

        require(index == core.ONE() + 2.5 ether);
        require(core.userIndex(sMaia, user) == index);
        require(core.rewardsAccrued(user) == 2.5 ether);
        require(core.rewardsAccrued(user2) == 7.5 ether);
        require(accrued == 2.5 ether);
        require(accrued2 == 7.5 ether);

        require(rewardToken.balanceOf(address(rewards)) == 10 ether);
    }

    function testAccrueSecondUserLater() public {
        testStake(user, 1 ether);

        rewardToken.mint(address(rewards), 10 ether);
        rewards.setRewardsAmount(sMaia, 10 ether);

        core.addStrategyForRewards(sMaia);

        (uint256 accrued, uint256 accrued2) = core.accrue(sMaia, user, user2);

        (uint224 index, ) = core.strategyState(sMaia);

        require(index == core.ONE() + 10 ether);
        require(core.userIndex(sMaia, user) == index);
        require(core.rewardsAccrued(user) == 10 ether);
        require(core.rewardsAccrued(user2) == 0);
        require(accrued == 10 ether);
        require(accrued2 == 0);

        require(rewardToken.balanceOf(address(rewards)) == 10 ether);

        testStake(user2, 3 ether);

        rewardToken.mint(address(rewards), 4 ether);
        rewards.setRewardsAmount(sMaia, 4 ether);

        (accrued, accrued2) = core.accrue(sMaia, user, user2);

        (index, ) = core.strategyState(sMaia);

        require(index == core.ONE() + 11 ether);
        require(core.userIndex(sMaia, user) == index);
        require(core.rewardsAccrued(user) == 11 ether);
        require(core.rewardsAccrued(user2) == 3 ether);
        require(accrued == 11 ether);
        require(accrued2 == 3 ether);

        require(rewardToken.balanceOf(address(rewards)) == 14 ether);
    }
}
