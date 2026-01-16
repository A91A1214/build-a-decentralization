// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CVGToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    uint256 public constant MINT_RATE = 1000;

    constructor(address initialOwner) 
        ERC20("CryptoVentures Governance", "CVG") 
        ERC20Permit("CryptoVentures Governance") 
        Ownable(initialOwner) 
    {}

    function stake() external payable {
        require(msg.value > 0, "CVG: Must stake ETH");
        uint256 cvgAmount = msg.value * MINT_RATE;
        _mint(msg.sender, cvgAmount);
        if (delegates(msg.sender) == address(0)) {
            _delegate(msg.sender, msg.sender);
        }
    }

    // Overrides
    function clock() public view virtual override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public view virtual override returns (string memory) {
        return "mode=timestamp";
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
