// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "./TestHelper.sol";

contract LiquidityBinPairLiquidityTest is TestHelper {
    function setUp() public {
        token6D = new ERC20MockDecimals(6);
        token18D = new ERC20MockDecimals(18);

        factory = new LBFactory(DEV);
        router = new LBRouter(ILBFactory(DEV), IWAVAX(DEV));

        pair = createLBPairDefaultFees(token6D, token18D);
    }

    function testConstructor(
        uint168 _maxAccumulator,
        uint16 _filterPeriod,
        uint16 _decayPeriod,
        uint16 _binStep,
        uint16 _baseFactor,
        uint16 _protocolShare,
        uint8 _variableFeeDisabled
    ) public {
        bytes32 _packedFeeParameters = bytes32(
            abi.encodePacked(
                _variableFeeDisabled,
                _protocolShare,
                _baseFactor,
                _binStep,
                _decayPeriod,
                _filterPeriod,
                _maxAccumulator
            )
        );

        LBPair lbPair = new LBPair(
            ILBFactory(DEV),
            token6D,
            token18D,
            DEFAULT_LOG2_VALUE,
            _packedFeeParameters
        );
        assertEq(address(lbPair.factory()), DEV);
        assertEq(address(lbPair.token0()), address(token6D));
        assertEq(address(lbPair.token1()), address(token18D));
        assertEq(lbPair.log2Value(), DEFAULT_LOG2_VALUE);

        FeeHelper.FeeParameters memory feeParameters = lbPair.feeParameters();
        assertEq(feeParameters.accumulator, 0);
        assertEq(feeParameters.time, 0);
        assertEq(feeParameters.maxAccumulator, _maxAccumulator);
        assertEq(feeParameters.filterPeriod, _filterPeriod);
        assertEq(feeParameters.decayPeriod, _decayPeriod);
        assertEq(feeParameters.binStep, _binStep);
        assertEq(feeParameters.baseFactor, _baseFactor);
        assertEq(feeParameters.protocolShare, _protocolShare);
        assertEq(feeParameters.variableFeeDisabled, _variableFeeDisabled);
    }

    function testAddLiquidity(uint256 _price) public {
        // Avoids Math__Exp2InputTooBig and very small x amounts
        vm.assume(_price < 5e42);
        // Avoids LBPair__BinReserveOverflows (very big x amounts)
        vm.assume(_price > 1e15);

        uint24 startId = getIdFromPrice(_price);

        uint256 amount1In = 1e12;

        (
            uint256[] memory _ids,
            uint256[] memory _liquidities,
            uint256 amount0In
        ) = spreadLiquidityN(amount1In * 2, startId, 3, 0);

        token6D.mint(address(pair), amount0In + 10);
        token18D.mint(address(pair), amount1In);

        pair.mint(_ids, _liquidities, DEV);

        console2.log("startId", startId);

        (, uint112 bin0Reserve0, uint112 bin0Reserve1) = pair.getBin(startId);
        (, uint112 binYReserve0, uint112 binYReserve1) = pair.getBin(
            startId - 1
        );
        (, uint112 binXReserve0, uint112 binXReserve1) = pair.getBin(
            startId + 1
        );

        console2.log("bin0", bin0Reserve0, bin0Reserve1);
        console2.log("binY", binYReserve0, binYReserve1);
        console2.log("binX", binXReserve0, binXReserve1);

        assertApproxEqRel(bin0Reserve0, amount0In / 3, 1e16, "bin0Reserve0");
        assertApproxEqRel(bin0Reserve1, amount1In / 3, 1e16, "bin0Reserve1");

        assertEq(binYReserve0, 0, "binYReserve0");
        assertApproxEqRel(
            binYReserve1,
            (amount1In * 2) / 3,
            1e16,
            "binYReserve1"
        );

        assertEq(binXReserve1, 0, "binXReserve0");
        assertApproxEqRel(
            binXReserve0,
            (amount0In * 2) / 3,
            1e16,
            "binXReserve1"
        );
        assertEq(binXReserve1, 0, "binXReserve0");
    }

    function testBurnLiquidity() public {
        uint256 amount1In = 3e12;
        (
            uint256[] memory _ids,
            uint256[] memory _liquidities,
            uint256 amount0In
        ) = spreadLiquidityN(amount1In * 2, ID_ONE, 3, 0);

        token6D.mint(address(pair), amount0In);
        token18D.mint(address(pair), amount1In);

        pair.mint(_ids, _liquidities, ALICE);

        token6D.mint(address(pair), amount0In);
        token18D.mint(address(pair), amount1In);

        pair.mint(_ids, _liquidities, BOB);

        uint256[] memory amounts = new uint256[](3);
        for (uint256 i; i < 3; i++) {
            amounts[i] = pair.balanceOf(BOB, _ids[i]);
        }

        vm.startPrank(BOB);
        pair.safeBatchTransferFrom(BOB, address(pair), _ids, amounts);
        pair.burn(_ids, _liquidities, BOB);
        vm.stopPrank();

        assertEq(token6D.balanceOf(BOB), amount0In);
        assertEq(token18D.balanceOf(BOB), amount1In);
    }
}
