// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title CVGTimelock
 * @dev Timelock controller that adds a delay toproposal execution.
 * Allows for emergency intervention by a guardian role.
 */
contract CVGTimelock is TimelockController {
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /**
     * @dev minDelay: minimum time delay (in seconds) that must pass before execution.
     * proposers: addresses that can propose execution.
     * executors: addresses that can execute proposals.
     * admin: address that can manage roles (usually the DAO).
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {
        _grantRole(GUARDIAN_ROLE, admin);
    }

    /**
     * @dev Cancel a queued proposal if a security issue is discovered.
     * Only callable by the guardian role.
     */
    function cancel(bytes32 id) public override onlyRole(GUARDIAN_ROLE) {
        super.cancel(id);
    }
}
