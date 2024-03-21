// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
    error DSCEngine__NotAllowedToken();
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__HealthFactorBelowMinimum(uint256 userHealthFactor);
    error DSCEngine__TokenAndPriceFeedAddressesMustBeSameLength();

    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_HEALTH_FACTOR = 1;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;

    address private owner;
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => uint256 amountDscMinted) private s_dscMinted;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    event CollateralDeposited(address indexed sender, address indexed token, uint256 indexed amountCollateral);

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) revert DSCEngine__NeedsMoreThanZero();
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) revert DSCEngine__NotAllowedToken();
        _;
    }

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

    function redeemCollateralForDsc() external {}
    function redeemCollateral() external {}

    /**
     *
     * @param dscAmountToMint The amount of Decentralized stablecoins to mint
     * @notice They must have more collateral value than minimum threshold.
     */
    function mintDsc(uint256 dscAmountToMint) public moreThanZero(dscAmountToMint) {
        s_dscMinted[msg.sender] += dscAmountToMint;

        // Revert if user has $100 worth ETH but they minted $250 worth DSC!
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, dscAmountToMint);
        if (!minted) revert DSCEngine__MintFailed();
    }

    function burnDsc() external {}
    function liquidate() external {}
    function getHealthFactor() external {}

    ////////////////////////////////////////
    //// Private and Internal Functions ////
    ////////////////////////////////////////

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
     */
    function _healthFactor(address user) private view returns (uint256) {
        // 1. Need total DSC minted
        // 2. Get their total collateral VALUE
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInFormation(user);
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
     */
    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
}
