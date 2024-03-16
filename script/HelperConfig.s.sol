// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {DSCEngine} from "../src/DSCEngine.sol";
import {Script, console} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    /**
     * @dev Get addresses from Chainlink pricefeeds
     */
    address public constant WETH = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81;
    address public constant WBTC = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address public constant WETH_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant WBTC_PRICE_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;

    NetworkConfig public activeNetwork;

    constructor() {
        if (block.chainid == 11155111) activeNetwork = getSepoliaConfig();
        else activeNetwork = getOrCreateAnvilConfig();
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory config) {
        return NetworkConfig({
            wethUsdPriceFeed: WETH_PRICE_FEED,
            wbtcUsdPriceFeed: WBTC_PRICE_FEED,
            weth: WETH,
            wbtc: WBTC,
            deployerKey: vm.envUint("RPRIVATE_KEY")
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory config) {
        if (activeNetwork.wethUsdPriceFeed != address(0)) return activeNetwork;
        vm.startBroadcast();
        MockV3Aggregator ethPriceFeeds = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);
        MockV3Aggregator btcPriceFeeds = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);
        vm.stopBroadcast();

        return NetworkConfig({
            wethUsdPriceFeed:address(ethPriceFeeds),
            wbtcUsdPriceFeed:address(btcPriceFeeds),
            weth:address(wethMock),
            wbtc:address(wbtcMock),
            deployerKey: vm.envUint("PRIVATE_KEY_ANVIL")
        });
    }
}
