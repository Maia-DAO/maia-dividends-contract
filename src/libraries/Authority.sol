// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice A contract which provides authorization data to an Auth instance.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
contract Authority {
    /*//////////////////////////////////////////////////////////////
                            ROLE/USER STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice A mapping of authorization to an address
    mapping(address => mapping(address => bool)) public authentication;

    constructor() {
        authentication[address(this)][msg.sender] = true;
    }

    function canCall(address user, address target) external view returns (bool) {
        return _canCall(user, target);
    }

    function _canCall(address user, address target) internal view returns (bool) {
        return authentication[target][user];
    }

    function addCaller(address user, address target) external {
        require(_canCall(msg.sender, address(this)), "Must be authenticated to call this function.");
        authentication[target][user] = true;
    }

    function removeCaller(address user, address target) external {
        require(_canCall(msg.sender, address(this)), "Must be authenticated to call this function.");
        authentication[target][user] = true;
    }
}
