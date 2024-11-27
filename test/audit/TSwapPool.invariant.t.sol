//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {TSwapPool} from "../../src/PoolFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {TSwapHandler} from "./FuzzHandler.t.sol";

contract AuditTSwapPoolTest is StdInvariant, Test {
    address admin = makeAddr("admin");
    address controlExpr = makeAddr("control-experiment");
    address[] actors;

    TSwapPool public liquidityPool;
    ERC20Mock public mockWETH;
    ERC20Mock public mockUSDC;
    TSwapHandler public fuzzHandler;

    uint256 public constant INIT_WETH_RESERVE = 10e18;
    uint256 public constant INIT_TOKEN_RESERVE = 45_000e18;

    function setUp() public {
        mockWETH = new ERC20Mock();
        mockUSDC = new ERC20Mock();
        liquidityPool = new TSwapPool(
            address(mockUSDC),
            address(mockWETH),
            "TSwapLP::USDC-WETH",
            "USDC-WETH"
        );

        vm.startPrank(admin);
        mockWETH.mint(admin, INIT_WETH_RESERVE);
        mockWETH.mint(controlExpr, INIT_WETH_RESERVE);
        mockUSDC.mint(admin, INIT_TOKEN_RESERVE);
        mockUSDC.mint(controlExpr, INIT_TOKEN_RESERVE);

        mockWETH.approve(address(liquidityPool), INIT_WETH_RESERVE);
        mockUSDC.approve(address(liquidityPool), INIT_TOKEN_RESERVE);

        liquidityPool.deposit(
            mockWETH.balanceOf(admin),
            mockWETH.balanceOf(admin),
            mockUSDC.balanceOf(admin),
            uint64(block.timestamp)
        );
        vm.stopPrank();

        actors.push(makeAddr("alice"));
        actors.push(makeAddr("bob"));
        actors.push(makeAddr("charlie"));
        actors.push(makeAddr("david"));
        actors.push(makeAddr("eunice"));

        for (uint256 i = 0; i < actors.length; ) {
            mockWETH.mint(actors[i], INIT_WETH_RESERVE);
            mockUSDC.mint(actors[i], INIT_TOKEN_RESERVE);

            unchecked {
                ++i;
            }
        }

        fuzzHandler = new TSwapHandler(
            mockWETH,
            mockUSDC,
            liquidityPool,
            actors
        );
        bytes4[] memory invariantSelectors = new bytes4[](1);
        invariantSelectors[0] = fuzzHandler.depositLiquidity.selector;

        targetContract(address(fuzzHandler));
        targetSelector(
            FuzzSelector({
                addr: address(fuzzHandler),
                selectors: invariantSelectors
            })
        );
    }

    function test_assertInitState() public view {
        assert(mockWETH.balanceOf(admin) == 0);
        assert(mockUSDC.balanceOf(admin) == 0);
        assert(mockWETH.balanceOf(controlExpr) == INIT_WETH_RESERVE);
        assert(mockUSDC.balanceOf(controlExpr) == INIT_TOKEN_RESERVE);

        assert(mockWETH.balanceOf(address(liquidityPool)) == INIT_WETH_RESERVE);
        assert(
            mockUSDC.balanceOf(address(liquidityPool)) == INIT_TOKEN_RESERVE
        );
        assert(liquidityPool.balanceOf(admin) == INIT_WETH_RESERVE);

        for (uint256 i = 0; i < actors.length; ) {
            assert(mockWETH.balanceOf(actors[i]) == INIT_WETH_RESERVE);
            assert(mockUSDC.balanceOf(actors[i]) == INIT_TOKEN_RESERVE);

            unchecked {
                ++i;
            }
        }
    }

    function testFuzz_getPoolTokensToDepositBasedOnWeth(
        uint256 fuzzAmount
    ) public view {
        uint256 poolWethBalance = mockWETH.balanceOf(address(liquidityPool));
        uint256 poolTokenBalance = mockUSDC.balanceOf(address(liquidityPool));

        fuzzAmount = bound(
            fuzzAmount,
            liquidityPool.getMinimumWethDepositAmount(),
            type(uint256).max / poolTokenBalance
        );
        uint256 tokenDeposit = liquidityPool.getPoolTokensToDepositBasedOnWeth(
            fuzzAmount
        );

        assert(
            (tokenDeposit / fuzzAmount) == (poolTokenBalance / poolWethBalance)
        );
    }

    function statefulFuzz_testLiquidityRatio() public view {
        uint256 depositedWETH = mockWETH.balanceOf(address(liquidityPool));
        uint256 depositedUSDC = mockUSDC.balanceOf(address(liquidityPool));

        assert(
            INIT_TOKEN_RESERVE / INIT_WETH_RESERVE ==
                depositedUSDC / depositedWETH
        );
    }
}
