// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {OracleLib} from "./libraries/OracleLib.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
 *
 * @dev Chainlink provides address to ETH/Usd pricefeed. So for each token(ETH/BTC...), we store the pricefeed
 * provided by chainlink into s_priceFeeds which we can leverage to get current Usd value for that token.
 * Reference: https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1
 */
contract DSCEngine is ReentrancyGuard {
    error DSCEngine__MintFailed();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__HealthFactorNotImproved();
    error DSCEngine__TokenAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__HealthFactorBelowMinimum(uint256 userHealthFactor);

    ///////////
    // Types //
    ///////////

    using OracleLib for AggregatorV3Interface;

    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10; // this means a 10% bonus
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;

    address private owner;
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => uint256 amountDscMinted) private s_dscMinted;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    event CollateralDeposited(address indexed sender, address indexed token, uint256 indexed amountCollateral);
    event CollateralRedeemed(
        address indexed redeemed_from, address indexed redeemed_to, address indexed token, uint256 amountCollateral
    );

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) revert DSCEngine__NeedsMoreThanZero();
        _;
    }

    /**
     * @dev Add address to DSCEngine__NotAllowedToken, so developers know which token is not allowed.
     */
    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) revert DSCEngine__NotAllowedToken();
        _;
    }

    /**
     * @notice Double spending vulnerability - Whitelisted collateral addresses are registered along
     * with their priceFeedAddresses. 
     * 
     * The registeration process below doesn't verify that token can be registered twice, or if addresses
     * passed are zero addresses! For address(0), user experience would fall
     * This affects getCollateralValueInUsd(). IF user deposits 10 ETH collateral, getCollateralValueInUsd
     * would return 20 ETH leading to double spending. 
     */
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAndPriceFeedAddressesMustBeSameLength();
        }
        owner = msg.sender;
        i_dsc = DecentralizedStableCoin(dscAddress);

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
    }

    /**
     * @dev depositCollateralAndMintDsc is a combo of depositCollateral and mintDsc function.
     * @param tokenCollateralAddress Address of collateral to deposit
     * @param amountCollateral Amount worth of tokens to deposit
     * @param dscAmountToMint Amount of dsc to mint
     *
     * @notice This function will deposit your collateral and mint DSC in one transaction.
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 dscAmountToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(dscAmountToMint);
    }

    /**
     * @param tokenCollateralAddress Address of token to deposit as collateral
     * @param amountCollateral Amount of token to deposit as collateral
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) revert DSCEngine__TransferFailed();
    }

    /**
     *
     * @param tokenCollateralAddress Collateral address to redeem
     * @param amountCollateral Amount of collateral to redeem
     * @param dscAmountToBurn Amount of DSC to burn
     *
     * @notice This functions burns dsc and redeems collateral in one transaction.
     */
    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 dscAmountToBurn)
        external
    {
        burnDsc(dscAmountToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // Redeem collateral checks health factor.
    }

    /**
     * @notice In order to redeem collateral, Health factor must be over 1e18 AFTER collateral pulled.
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     *
     * @param dscAmountToMint The amount of Decentralized stablecoins to mint
     * @notice They must have more collateral value than minimum threshold.
     * @notice Consider adding events for crucial operations; minting, burning, liquidate.
     * Otherwise, off-chain applications won't be notified if something has happened on blockchain.
     */
    function mintDsc(uint256 dscAmountToMint) public moreThanZero(dscAmountToMint) {
        s_dscMinted[msg.sender] += dscAmountToMint;

        // Revert if user has $100 worth ETH but they minted $250 worth DSC!
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, dscAmountToMint);

        /**
         * @dev i_dsc.mint() either reverts or returns true, so the if statement below is meaningless!
         * Remove redundant code
         */
        if (!minted) revert DSCEngine__MintFailed();
    }


    /**
     * @notice Improvements - Consider removing _revertIfHealthFactorIsBroken from burnDsc. 
     * Use case - If a user's HF is below threshold and they want to burn their
     * DSC to improve the HF, they won't be able to do so, since their health factor
     * is broken.
     */
    function burnDsc(uint256 dscAmountToBurn) public moreThanZero(dscAmountToBurn) {
        _burnDsc(dscAmountToBurn, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // I don't think this will ever hit...
    }

    /**
     * @param collateral ERC20 collateral to liquidate from user
     * @param user The user who has broken health factor. Their _healthFactor should be above
     * MIN_HEALTH_FACTOR
     * @param debtToCover Amount of DSC you want to burn to improve user's health factor.
     *
     * @notice Liquidates positions if individuals are undercollateralized.
     * If someone is undercollateralized, we will pay you to liquidate them.
     * Liquidator can burn their debtToCover dsc and get all the collateral of user
     * effectively removing the user from the system.
     * @notice You can partially liquidate a user
     * @notice You can get liquidation bonus for taking user funds.
     * @notice This function assumes that protocol working is roughly 200% overcollateralized
     * in order for this to work.
     * @notice A known bug would be if the protocol were 100% or less collateralized, then we wouldn't be
     * able to incentivize users
     * For example: If price of collateral plummeted before anyone could be liquidated.
     * 
     * @notice Vulnerability - liquidate doesn't allow liquidator to liquidate user if
     *  liquidator health factor < 1. Liquidator should be allowed to liquidate user if 
     * liquidator's HF is below 1 since they're burning their own funds to cover the debt 
     * that doesn't impact their HF directly!
     * Recommendations: The system should remove the check _revertIfHealthFactorIsBroken(msg.sender); in the liquidate() function, 
     * allowing a liquidator to always be able to liquidate a borrower.
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) revert DSCEngine__HealthFactorOk();

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalAmountToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(user, msg.sender, collateral, totalAmountToRedeem);
        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingHealthFactor = _healthFactor(user);
        if (endingHealthFactor <= startingUserHealthFactor) revert DSCEngine__HealthFactorNotImproved();
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor(address user) external view returns (uint256 healthFactor) {
        healthFactor = _healthFactor(user);
    }

    function calculateHealthFactor(uint256 collateralValueInUsd, uint256 totalDscMinted) external pure returns (uint256) {
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    ////////////////////////////////////////
    //// Private and Internal Functions ////
    ////////////////////////////////////////

    /**
     * @dev Low level function. Do not call unless the function calling it is checking for health factors
     */
    function _burnDsc(uint256 dscAmountToBurn, address onBehalfOf, address dscFrom)
        public
        moreThanZero(dscAmountToBurn)
    {
        /**
         * @notice Vulnerability here - DoS of full liquidations are possible by frontrunning the liquidator.
         * If liquidator tries to liquidate a user and user tries to frontrun the liquidator by liquidating small
         * amounts of their own position using a secondary address, then liquidator won't be able to liquidate them. 
         * Liquidator needs to provide precise amount of amountToLiquidate which would be subtracted from user's account.
         *  What if user has less than the amountToLiquidate? 
         * The transaction would revert due to underflow, preventing full liquidation.
         * Recommendations: Consider allowing liquidator to provide type(uint256).max as argument to debtToCover
         * In liquidate, check for,
         * if debtToCover == type(uint256).max:
         *      (uint256 dscMinted,) = engine.getAccountInFormation(user);
         *      debtToCover = dscMinted // This would prevent underflow, providing precise value.
         */
        s_dscMinted[onBehalfOf] -= dscAmountToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), dscAmountToBurn);

        /**
         * @dev The if statement below never hits since i_dsc.transferFrom() either reverts if false
         *  or returns true. Remove redundant code.
         */
        if (!success) revert DSCEngine__TransferFailed();
        i_dsc.burn(dscAmountToBurn);
    }

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) revert DSCEngine__TransferFailed();
    }

    function _getAccountInFormation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_dscMinted[user];
        collateralValueInUsd = getCollateralValueInUsd(user);
    }

    /**
     * Returns how close to liquidation a user is.
     * @dev If totalDscMinted is 0, it should return max health factor. Current code breaks.
     */
    function _healthFactor(address user) private view returns (uint256) {
        // 1. Need total DSC minted
        // 2. Get their total collateral VALUE
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInFormation(user);
        if (totalDscMinted == 0) return type(uint256).max;
        /**
         * @dev In order to make the system 200% overcollateralized, we half the total collateral of a user.
         * User would need to deposit double the amount everytime in order to not get liquidated.
         * LIQUIDATION_THRESHOLD = 50
         * LIQUIDATION_PRECISION = 100
         * 50/100 = 1/2 = 0.5
         * 
         */
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) revert DSCEngine__HealthFactorBelowMinimum(userHealthFactor);
    }

    //////////////////////////
    //// Public Functions ////
    //////////////////////////

    function getAccountInFormation(address user)
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        (totalDscMinted, collateralValueInUsd) = _getAccountInFormation(user);
    }

    /**
     * @notice The code below assumes that all tokens have 18 decimals, thus given the
     * token's amount_in_wei * PRECISION (1e18).
     * Vulnerability lies in the assumption that all tokens have 18 decimals (represented by PRECISION).
     * This could lead to miscalculation for tokens for fewer decimals since the output returned will
     * not have e18 decimals! So amount_in_wei * 1e18 is not logical for such tokens and calculations breaks apart. 
     * 
     * RETURNS tokenAmounte18 -> The return value always has 18 decimals (assumption) 
    */
    function getTokenAmountFromUsd(address token, uint256 amount_in_wei) public view returns (uint256 tokenAmount) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        tokenAmount = (amount_in_wei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    /**
     * @notice Vulnerability alert! totalCollateralValueInUsd is incorrect because terms of sum may have different
     * decimals, and therefore different frames of reference. 
     */
    function getCollateralValueInUsd(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // Loop through collateral deposited, map each to its usd price and get total by summing them up.
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amountDeposited = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amountDeposited);
        }
    }

    /**
     * @dev price from latestRoundData is of price * 1e8 decimal places while
     * amount is 1e18. So we multiply by additional precision to balance it out
     * and divide the whole thing by 1e18 since the return value of function
     * will be too large.
     * 
     * @notice Decimal discrepancy vulnerability in this - Returns same decimals as
     * token decimals instead of 18-decimal USD value.
     */
    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.stalePriceCheck();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    //////////////////////////
    //// Getter Functions ////
    //////////////////////////

    function getAdditionalFeedPrecision() public pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getPrecision() public pure returns (uint256) {
        return PRECISION;
    }

    function getTotalDscMintedByAUser(address user) public view returns (uint256) {
        return s_dscMinted[user];
    } 

    function getCollateralTokenPriceFeed(address token) public view returns (address) {
        return s_priceFeeds[token];
    }

    function getTotalCollateralValueOfUser(address user, address token) public view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }
}
