// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title CVGTreasury
 * @dev Manages DAO funds with different allocation categories and spending controls.
 */
contract CVGTreasury is AccessControl {
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    enum FundCategory { HighConviction, Experimental, Operational }

    struct Allocation {
        uint256 balanceLimit;
        uint256 spent;
    }

    mapping(FundCategory => Allocation) public allocations;

    event FundsReceived(address indexed sender, uint256 amount);
    event FundsWithdrawn(address indexed recipient, uint256 amount, FundCategory category);
    event AllocationUpdated(FundCategory category, uint256 newLimit);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        
        // Initialize default limits
        allocations[FundCategory.HighConviction].balanceLimit = 1000 ether;
        allocations[FundCategory.Experimental].balanceLimit = 100 ether;
        allocations[FundCategory.Operational].balanceLimit = 10 ether;
    }

    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    /**
     * @dev Withdraw funds from the treasury. Only callable by DAO executor.
     */
    function withdraw(
        address payable recipient, 
        uint256 amount, 
        FundCategory category
    ) external onlyRole(EXECUTOR_ROLE) {
        require(address(this).balance >= amount, "Treasury: Insufficient balance");
        
        Allocation storage alloc = allocations[category];
        require(alloc.spent + amount <= alloc.balanceLimit, "Treasury: Exceeds category limit");

        alloc.spent += amount;
        recipient.transfer(amount);

        emit FundsWithdrawn(recipient, amount, category);
    }

    /**
     * @dev Update allocation limits. Only callable by admin.
     */
    function updateAllocationLimit(FundCategory category, uint256 newLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        allocations[category].balanceLimit = newLimit;
        emit AllocationUpdated(category, newLimit);
    }

    /**
     * @dev Get total treasury balance.
     */
    function totalBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
