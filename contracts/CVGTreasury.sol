// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract CVGTreasury is AccessControl {
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    enum FundCategory {
        HighConviction,
        Experimental,
        Operational
    }

    struct Allocation {
        uint256 limit;
        uint256 spent;
    }

    mapping(FundCategory => Allocation) public allocations;

    event FundsReceived(address indexed from, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount, FundCategory category);
    event AllocationUpdated(FundCategory category, uint256 newLimit);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        allocations[FundCategory.HighConviction].limit = 1000 ether;
        allocations[FundCategory.Experimental].limit = 100 ether;
        allocations[FundCategory.Operational].limit = 10 ether;
    }

    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }

    function withdraw(
        address payable recipient,
        uint256 amount,
        FundCategory category
    ) external onlyRole(EXECUTOR_ROLE) {
        require(address(this).balance >= amount, "Treasury: Insufficient balance");

        Allocation storage alloc = allocations[category];
        require(alloc.spent + amount <= alloc.limit, "Treasury: Category limit exceeded");

        alloc.spent += amount;
        recipient.transfer(amount);

        emit FundsWithdrawn(recipient, amount, category);
    }

    function updateAllocationLimit(
        FundCategory category,
        uint256 newLimit
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        allocations[category].limit = newLimit;
        emit AllocationUpdated(category, newLimit);
    }

    function totalBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
