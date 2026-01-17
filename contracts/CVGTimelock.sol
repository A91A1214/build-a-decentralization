// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract CVGTimelock is TimelockController {
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {
        _grantRole(GUARDIAN_ROLE, admin);
    }

    /**
     * @dev Emergency cancellation by guardian
     */
    function cancel(bytes32 id) public override onlyRole(GUARDIAN_ROLE) {
        super.cancel(id);
    }
}
