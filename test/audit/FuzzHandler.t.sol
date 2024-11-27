// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test, console} from "forge-std/Test.sol";
import {TSwapPool} from "../../src/PoolFactory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TSwapHandler is Test {
    address[] public actors;
    IERC20 public WETH;
    IERC20 public TOKEN;
    TSwapPool public culprit_contract;

    constructor(
        IERC20 _weth,
        IERC20 _token,
        TSwapPool _liquidityPool,
        address[] memory _actors
    ) {
        WETH = _weth;
        TOKEN = _token;
        culprit_contract = _liquidityPool;

        for (uint256 i = 0; i < _actors.length; ) {
            actors.push(_actors[i]);
            unchecked {
                ++i;
            }
        }
    }

    function depositLiquidity(
        uint256 actorIndex,
        uint256 fuzzWethDeposit
    ) public {
        uint256 i = bound(actorIndex, 0, actors.length - 1);
        address actor = actors[i];

        if (
            WETH.balanceOf(actor) <
            culprit_contract.getMinimumWethDepositAmount()
        ) return;

        uint256 wethDeposit = bound(
            fuzzWethDeposit,
            culprit_contract.getMinimumWethDepositAmount(),
            WETH.balanceOf(actor)
        );
        uint256 maxTokenDeposit = culprit_contract
            .getPoolTokensToDepositBasedOnWeth(wethDeposit);

        vm.startPrank(actor);
        WETH.approve(address(culprit_contract), wethDeposit);
        TOKEN.approve(address(culprit_contract), maxTokenDeposit);

        culprit_contract.deposit(
            wethDeposit,
            (wethDeposit * culprit_contract.totalSupply()) /
                WETH.balanceOf(address(culprit_contract)),
            maxTokenDeposit,
            uint64(block.timestamp)
        );
        vm.stopPrank();
    }
}
