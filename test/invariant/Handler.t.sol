// SPDX-License-Identifier: MIT

// Handler narrows function calls
// For example, we don't want redeemCollateral to be called by invariant before anything is deposited.
// Otherwise, it would be wasting time and resources. Handler gives things order. 


pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract Handler is Test {

    DSCEngine engine;
    DecentralizedStableCoin dsc;

    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc) {
        engine = _engine;
        dsc = _dsc;
    }

    function depositCollateral(address collateral, uint256 amountCollateral) public {
        engine.depositCollateral(collateral, amountCollateral);
    }
}


// https://www.youtube.com/watch?v=wUjYK5gwNZs
// 3:46:01