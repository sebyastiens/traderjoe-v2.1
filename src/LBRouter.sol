// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

//import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol"; // BEFORE
import {IERC20} from "./interfaces/IERC20.sol";

import {BinHelper} from "./libraries/BinHelper.sol";
import {Constants} from "./libraries/Constants.sol";
import {Encoded} from "./libraries/math/Encoded.sol";
import {FeeHelper} from "./libraries/FeeHelper.sol";
import {JoeLibrary} from "./libraries/JoeLibrary.sol";
import {LiquidityConfigurations} from "./libraries/math/LiquidityConfigurations.sol";
import {PackedUint128Math} from "./libraries/math/PackedUint128Math.sol";
import {TokenHelper} from "./libraries/TokenHelper.sol";
import {Uint256x256Math} from "./libraries/math/Uint256x256Math.sol";

import {IJoePair} from "./interfaces/IJoePair.sol";
import {ILBPair} from "./interfaces/ILBPair.sol";
import {ILBLegacyPair} from "./interfaces/ILBLegacyPair.sol";
import {ILBToken} from "./interfaces/ILBToken.sol";
import {ILBRouter} from "./interfaces/ILBRouter.sol";
import {ILBLegacyRouter} from "./interfaces/ILBLegacyRouter.sol";
import {IJoeFactory} from "./interfaces/IJoeFactory.sol";
import {ILBLegacyFactory} from "./interfaces/ILBLegacyFactory.sol";
import {ILBFactory} from "./interfaces/ILBFactory.sol";
import {IWNATIVE} from "./interfaces/IWNATIVE.sol";

/**
 * @title Liquidity Book Router
 * @author Trader Joe
 * @notice Main contract to interact with to swap and manage liquidity on Joe V2 exchange.
 */
contract LBRouter is ILBRouter {
    using TokenHelper for IERC20;
    using TokenHelper for IWNATIVE;
    using JoeLibrary for uint256;
    using PackedUint128Math for bytes32;

    ILBFactory private immutable _factory;
    IJoeFactory private immutable _factoryV1;
    ILBLegacyFactory private immutable _legacyFactory;
    ILBLegacyRouter private immutable _legacyRouter;
    IWNATIVE private immutable _wnative;

    modifier onlyFactoryOwner() {
        if (msg.sender != _factory.owner()) revert LBRouter__NotFactoryOwner();
        _;
    }

    modifier ensure(uint256 deadline) {
        if (block.timestamp > deadline) revert LBRouter__DeadlineExceeded(deadline, block.timestamp);
        _;
    }

    modifier verifyPathValidity(Path memory path) {
        if (
            path.pairBinSteps.length == 0 || path.versions.length != path.pairBinSteps.length
                || path.pairBinSteps.length + 1 != path.tokenPath.length
        ) revert LBRouter__LengthsMismatch();
        _;
    }

    /**
     * @notice Constructor
     * @param factory Address of Joe V2.1 factory
     * @param factoryV1 Address of Joe V1 factory
     * @param legacyFactory Address of Joe V2 factory
     * @param legacyRouter Address of Joe V2 router
     * @param wnative Address of WNATIVE
     */
    constructor(
        ILBFactory factory,
        IJoeFactory factoryV1,
        ILBLegacyFactory legacyFactory,
        ILBLegacyRouter legacyRouter,
        IWNATIVE wnative
    ) {
        _factory = factory;
        _factoryV1 = factoryV1;
        _legacyFactory = legacyFactory;
        _legacyRouter = legacyRouter;
        _wnative = wnative;
    }

    /**
     * @dev Receive function that only accept NATIVE from the WNATIVE contract
     */
    receive() external payable {
        if (msg.sender != address(_wnative)) revert LBRouter__SenderIsNotWNATIVE();
    }

    /**
     * View function to get the factory V2.1 address
     * @return lbFactory The address of the factory V2.1
     */
    function getFactory() external view override returns (ILBFactory lbFactory) {
        return _factory;
    }

    /**
     * View function to get the factory V2 address
     * @return legacyLBfactory The address of the factory V2
     */
    function getLegacyFactory() external view override returns (ILBLegacyFactory legacyLBfactory) {
        return _legacyFactory;
    }

    /**
     * View function to get the factory V1 address
     * @return factoryV1 The address of the factory V1
     */
    function getV1Factory() external view override returns (IJoeFactory factoryV1) {
        return _factoryV1;
    }

    /**
     * View function to get the router V2 address
     * @return legacyRouter The address of the router V2
     */
    function getLegacyRouter() external view override returns (ILBLegacyRouter legacyRouter) {
        return _legacyRouter;
    }

    /**
     * View function to get the WNATIVE address
     * @return wnative The address of WNATIVE
     */
    function getWNATIVE() external view override returns (IWNATIVE wnative) {
        return _wnative;
    }

    /**
     * @notice Returns the approximate id corresponding to the inputted price.
     * Warning, the returned id may be inaccurate close to the start price of a bin
     * @param pair The address of the LBPair
     * @param price The price of y per x (multiplied by 1e36)
     * @return The id corresponding to this price
     */
    function getIdFromPrice(ILBPair pair, uint256 price) external view override returns (uint24) {
        return pair.getIdFromPrice(price);
    }

    /**
     * @notice Returns the price corresponding to the inputted id
     * @param pair The address of the LBPair
     * @param id The id
     * @return The price corresponding to this id
     */
    function getPriceFromId(ILBPair pair, uint24 id) external view override returns (uint256) {
        return pair.getPriceFromId(id);
    }

    /**
     * @notice Simulate a swap in
     * @param pair The address of the LBPair
     * @param amountOut The amount of token to receive
     * @param swapForY Whether you swap X for Y (true), or Y for X (false)
     * @return amountIn The amount of token to send in order to receive amountOut token
     * @return amountOutLeft The amount of token Out that can't be returned due to a lack of liquidity
     * @return fee The amount of fees paid in token sent
     */
    function getSwapIn(ILBPair pair, uint128 amountOut, bool swapForY)
        public
        view
        override
        returns (uint128 amountIn, uint128 amountOutLeft, uint128 fee,uint24 id)
    {
        (amountIn, amountOutLeft, fee, id) = pair.getSwapIn(amountOut, swapForY);
    }

    /**
     * @notice Simulate a swap out
     * @param pair The address of the LBPair
     * @param amountIn The amount of token sent
     * @param swapForY Whether you swap X for Y (true), or Y for X (false)
     * @return amountInLeft The amount of token In that can't be swapped due to a lack of liquidity
     * @return amountOut The amount of token received if amountIn tokenX are sent
     * @return fee The amount of fees paid in token sent
     */
    function getSwapOut(ILBPair pair, uint128 amountIn, bool swapForY)
        external
        view
        override
        returns (uint128 amountInLeft, uint128 amountOut, uint128 fee, uint24 id)
    {
        (amountInLeft, amountOut, fee, id) = pair.getSwapOut(amountIn, swapForY);
    }

}
