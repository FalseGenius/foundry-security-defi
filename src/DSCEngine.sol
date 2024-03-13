// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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
contract DSCEngine is ReentrancyGuard {

    error DSCEngine__NotAllowedToken();
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAndPriceFeedAddressesMustBeSameLength();

    mapping(address token => address priceFeed) private s_priceFeeds;
    address private owner;
    
    DecentralizedStableCoin private immutable i_dsc;

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) revert DSCEngine__NeedsMoreThanZero();
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) revert DSCEngine__NotAllowedToken();
        _;
    }

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) revert DSCEngine__TokenAndPriceFeedAddressesMustBeSameLength();
        owner = msg.sender;
        i_dsc = DecentralizedStableCoin(dscAddress);
        
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }
    }


    function depositCollateralAndMintDsc() external {}

    /**
     * @param tokenCollateralAddress Address of token to deposit as collateral
     * @param amountCollateral Amount of token to deposit as collateral
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral) external 
    moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) nonReentrant {

    }

    function redeemCollateralForDsc() external {}
    function redeemCollateral() external {}
    function mintDsc() external {}
    function burnDsc() external {}
    function liquidate() external {}
    function getHealthFactor() external {}

}