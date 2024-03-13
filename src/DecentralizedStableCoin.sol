// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Decentralized Stablecoin 
 * @author FalseGenius
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 * 
 * @notice This contract is governed by DSCEngine. This contract is ERC20 implementation of stablecoin system.
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable(msg.sender) {

    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__AmoutCannotBeZero();

    constructor() ERC20("DecentralizedStableCoin", "DSC") {
        
    }

    /**
     * @dev super keyword indicates that burn should be used from the parent class
     */
    function burn(uint256 _amount) public override {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) revert DecentralizedStableCoin__AmoutCannotBeZero();
        if (balance < _amount) revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        super.burn(_amount);
        
    }
    
}