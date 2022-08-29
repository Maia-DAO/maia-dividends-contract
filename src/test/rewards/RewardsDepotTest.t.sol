// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {RewardsDepot} from "../../rewards/MaiaDynamicRewards.sol";

import {Auth, Authority} from "../../libraries/Auth.sol";

contract RewardsDepotTest is DSTestPlus {
    MockERC20 strategy;
    MockERC20 public rewardToken;
    RewardsDepot public depot;

    Authority public authority;

    function setUp() public {
        rewardToken = new MockERC20("test token", "TKN", 18);

        authority = new Authority();

        depot = new RewardsDepot(rewardToken, address(this), authority, address(this));
    }

    function testGetRewards() public {
        rewardToken.mint(address(depot), 100 ether);

        depot.getRewards();

        require(rewardToken.balanceOf(address(this)) == 100 ether);
    }

    function testGetRewardsNoAvailable() public {
        depot.getRewards();

        require(rewardToken.balanceOf(address(this)) == 0);
    }

    function testGetRewardsNotAllowed() public {
        rewardToken.mint(address(depot), 100 ether);

        hevm.prank(address(1));
        hevm.expectRevert(bytes("UNAUTHORIZED"));
        depot.getRewards();

        require(rewardToken.balanceOf(address(this)) == 0);
        require(rewardToken.balanceOf(address(depot)) == 100 ether);
    }

    function testGetRewardsTwice() public {
        rewardToken.mint(address(depot), 100 ether);

        depot.getRewards();

        require(rewardToken.balanceOf(address(this)) == 100 ether);

        rewardToken.mint(address(depot), 100 ether);

        depot.getRewards();

        require(rewardToken.balanceOf(address(this)) == 200 ether);
    }

    function testGetRewardsTwiceFirstHasNothing() public {
        depot.getRewards();

        require(rewardToken.balanceOf(address(this)) == 0 ether);

        rewardToken.mint(address(depot), 100 ether);

        depot.getRewards();

        require(rewardToken.balanceOf(address(this)) == 100 ether);
    }

}
