// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;


/**
 * @title DSCEngine
 * @author False Genius
 * This system is designed to be as minimal as possible, and have tokens maintain a 1 token == $1 peg.
 * 
 * This stablecoin has the following properties:
 *      1. Exogenous Collateral
 *      2. Dollar pegged
 *      3. Algorithmically stable
 * 
 * It is simmilar to DAI if DAI had no governance, no fees and only backed by WETH and WBTC.
 * 
 * Our DSC system should always be "Overcollateralized". At no point should the value of all collateral be  <= value
 * of all $ backed DSC.
 * 
 * @notice This contract is the CORE of DSC system. It handles all the logic for mining and redeeming DSC, as
 * well as depositing & withdrawing collateral.
 * @notice This contract is very loosely based on MakerDSS (DAI) system.
 */
contract DSCEngine {

    function depositCollateralAndMintDsc() external {}
    function depositCollateral() external {}
    function redeemCollateralForDsc() external {}
    function redeemCollateral() external {}
    function mintDsc() external {}
    function burnDsc() external {}
    function liquidate() external {}
    function getHealthFactor() external {}

}