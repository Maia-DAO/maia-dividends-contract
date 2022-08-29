// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {Auth, Authority} from "../libraries/Auth.sol";

import {FlywheelDynamicRewards} from "./FlywheelDynamicRewards.sol";
import {RewardsDepot} from "./RewardsDepot.sol";
import {FlywheelCore} from "../FlywheelCore.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/// @notice a contract which streams reward tokens to the FlywheelRewards module
interface IRewardsDepot {
    /// @notice read and transfer reward token chunk to FlywheelRewards module
    function getRewards() external returns (uint256);
}

/** 
 @title Flywheel Dynamic Reward Stream
 @notice Determines rewards based on a dynamic reward stream.
         Rewards are transferred linearly over a "rewards cycle" to prevent gaming the reward distribution. 
         The reward source can be arbitrary logic, but most common is to "pass through" rewards from some other source.
         The getNextCycleRewards() hook should also transfer the next cycle's rewards to this contract to ensure proper accounting.
*/
contract MaiaDynamicRewards is FlywheelDynamicRewards, Auth {
    using SafeTransferLib for ERC20;
    using SafeCastLib for uint256;

    /// @notice RewardsDepot for each strategy
    mapping(ERC20 => RewardsDepot) public rewardsDepot;

    constructor(
        FlywheelCore _flywheel,
        uint32 _rewardsCycleLength,
        Authority _authority,
        address _owner
    ) FlywheelDynamicRewards(_flywheel, _rewardsCycleLength) Auth(_owner, _authority) {}

    //commented (ERC20 strategy)
    function getNextCycleRewards(ERC20 strategy) internal override returns (uint192) {
        return uint192(rewardsDepot[strategy].getRewards());
    }

    /// @notice swap out the flywheel rewards contract
    function setRewardsDepot(ERC20 strategy, RewardsDepot _rewardsDepot) external requiresAuth {
        rewardsDepot[strategy] = _rewardsDepot;
    }
}
