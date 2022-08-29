// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Multicall} from "../../lib/ERC4626/src/external/Multicall.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";

import {FlywheelCore} from "../FlywheelCore.sol";

import {IFlywheelRewards} from "../interfaces/IFlywheelRewards.sol";
import {IFlywheelBooster} from "../interfaces/IFlywheelBooster.sol";
import {Auth, Authority} from "../libraries/Auth.sol";

/**
@title Base Contract for Hermes Gauges 
@author Maia DAO
@notice Easily extendable contract designed to facilitate Hermes Custom Gauges integration. 
@dev Basic ERC-4626 Vault implementation where rewards token (HERMES) =/ deposit token (e.g. LP Token). 
*/

contract ERC20sMaia is ERC20, Auth {
    using FixedPointMathLib for uint256;

    /// @notice reward Managers.
    mapping(FlywheelCore => bool) public isFlywheel;

    /// @notice active Reward Managers.
    mapping(FlywheelCore => bool) public isFlywheelActive;

    /// @notice append-only list of strategies added.
    FlywheelCore[] public allFlywheels;

    /// @notice dsblvoors in dsblv
    ERC20 public maia;

    /// @notice maximum number of different reward assets allowed.
    uint256 immutable internal MAX_FLYWHEELS = 20;

    constructor(
        Authority _authority,
        address _owner,
        ERC20 _maia
    ) ERC20("Staked Maia", "sMAIA", 18) Auth(_owner, _authority) {
        maia = _maia;
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice simple re-entrancy check
    uint256 internal _unlocked = 1;
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                               REWARDS LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice get number of different reward assets.
    function getRewardsLenght() external view returns (uint256) {
        return allFlywheels.length;
    }

    /** 
      @notice accrue rewards for a user on a strategy
      @param user the first user to be accrued
    */
    function accrue(address user) external lock {
        _accrue(user);
    }

    /** 
      @notice accrue rewards for two users on a strategy
      @param user the first user to be accrued
      @param user the second user to be accrued
    */
    function accrue(address user, address secondUser) external lock {
        _accrue(user, secondUser);
    }

    /** 
      @notice accrue rewards for a user on a strategy
      @param user the first user to be accrued
    */
    function _accrue(address user) internal {
        FlywheelCore[] memory _allFlywheels = allFlywheels;
        uint256 length = _allFlywheels.length;
        for (uint256 i = 0; i < length; ) {
            if (isFlywheelActive[_allFlywheels[i]]) _allFlywheels[i].accrue(this, user);
            unchecked {
                i++;
            }
        }
    }

    /** 
      @notice accrue rewards for two users on a strategy
      @param user the first user to be accrued
      @param user the second user to be accrued
    */
    function _accrue(address user, address secondUser) internal {
        FlywheelCore[] memory _allFlywheels = allFlywheels;
        uint256 length = _allFlywheels.length;
        for (uint256 i = 0; i < length; ) {
            if (isFlywheelActive[_allFlywheels[i]]) _allFlywheels[i].accrue(this, user, secondUser);
            unchecked {
                i++;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                            ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function transfer(address to, uint256 amount) public override lock returns (bool) {
        _accrue(msg.sender, to);
        return super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override lock returns (bool) {
        _accrue(from, to);
        return super.transferFrom(from, to, amount);
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice add new FlywheelCore
    function addFlywheelCore(FlywheelCore flywheel) external requiresAuth {
        _addFlywheelCore(flywheel);
    }

    function _addFlywheelCore(FlywheelCore flywheel) internal {
        require(!isFlywheel[flywheel], "Flywheel already exists");
        require(allFlywheels.length < MAX_FLYWHEELS, "Max Flywheels");
        isFlywheel[flywheel] = true;
        isFlywheelActive[flywheel] = true;
        allFlywheels.push(flywheel);

        emit AddFlywheel(address(flywheel));
    }

    /// @notice toggles FlywheelCore
    function toggleFlywheel(FlywheelCore flywheel) external requiresAuth {
        require(isFlywheel[flywheel], "Flywheel doesn't exist");
        isFlywheelActive[flywheel] = !isFlywheelActive[flywheel];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function stake(address to, uint256 amount) external lock {
        _accrue(to);

        maia.transferFrom(msg.sender, address(this), amount);

        _mint(to, amount);
    }

    function unstake(address to, uint256 amount) external lock {
        _accrue(msg.sender);

        _burn(msg.sender, amount);

        maia.transfer(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /** 
      @notice Emitted when a new strategy is added to flywheel by the admin
      @param newFlywheel the new added strategy
    */
    event AddFlywheel(address indexed newFlywheel);
}
