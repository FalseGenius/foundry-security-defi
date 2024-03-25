// SPDX-License-Identifier: MIT

// Handler narrows function calls
// For example, we don't want redeemCollateral to be called by invariant before anything is deposited.
// Otherwise, it would be wasting time and resources. Handler gives things order. 


pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";


contract Handler is Test {

    DSCEngine engine;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
        engine = _engine;
        dsc = _dsc;

    }

    /**
     * @dev Instead of passing it random addresses, we'd want to pass only valid collateral address
     * in order to check protocolMustHaveMoreValueThanTotalSupply property.
     */
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        engine.depositCollateral(collateral, amountCollateral);
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock){
        if (collateralSeed % 2 == 0) {
            return weth;
        }
    }
}


// https://www.youtube.com/watch?v=wUjYK5gwNZs
// 3:52:02