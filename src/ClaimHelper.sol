// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC20sMAIA, FlywheelCore} from "./tokens/ERC20sMAIA.sol";

contract ClaimHelper {
    /// @notice accrue and claim for user.
    function accrueAndClaimRewards(ERC20sMAIA smaia, address user) external {
        smaia.accrue(user);
        uint256 length = smaia.getRewardsLenght();
        for (uint256 i = 0; i < length; ) {
            smaia.allFlywheels(i).claimRewards(user);
            unchecked {
                i++;
            }
        }
    }
}
