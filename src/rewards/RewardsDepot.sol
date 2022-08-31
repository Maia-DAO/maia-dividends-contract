// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {IFlywheelRewards} from "../interfaces/IFlywheelRewards.sol";

import {Auth, Authority} from "../libraries/Auth.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

/** 
 @title Flywheel Dynamic Reward Stream
 @notice Determines rewards based on a dynamic reward stream.
         Rewards are transferred linearly over a "rewards cycle" to prevent gaming the reward distribution. 
         The reward source can be arbitrary logic, but most common is to "pass through" rewards from some other source.
         The getNextCycleRewards() hook should also transfer the next cycle's rewards to this contract to ensure proper accounting.
*/
contract RewardsDepot is Auth {
    using SafeTransferLib for ERC20;
    using SafeCastLib for uint256;

    ERC20 asset;
    address rewardsContract;

    constructor(
        ERC20 _asset,
        address _rewards,
        Authority _authority,
        address _owner
    ) Auth(_owner, _authority) {
        asset = _asset;
        rewardsContract = _rewards;
    }

    /*///////////////////////////////////////////////////////////////
                            REWARDS CONTRACT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Return available reward amount and transfer them to rewardsContract.
    function getRewards() external returns (uint256 balance) {
        require(address(msg.sender) == rewardsContract, "UNAUTHORIZED");
        balance = asset.balanceOf(address(this));
        asset.transfer(rewardsContract, balance);
    }
}
