// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    
    address public owner;
    address public jointVenture;

    error OnlyOwner();
    error OnlyJointVentureContract();

    constructor(
        address _owner
    ) ERC20("Celo Workshop Token", "CWT") {
        owner = _owner;
    }

    function setJointVenture(address _jointVenture) external {
        if (msg.sender != owner) revert OnlyOwner();
        jointVenture = _jointVenture;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != owner) revert OnlyOwner();

        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        if (msg.sender != owner) revert OnlyOwner();

        _burn(from, amount);
    }

    function mintByContract(address to, uint256 amount) external {
        if (msg.sender != jointVenture) revert OnlyJointVentureContract();
        
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}