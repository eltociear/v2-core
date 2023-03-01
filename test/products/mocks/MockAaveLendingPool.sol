// SPDX-License-Identifier: Apache-2.0

pragma solidity =0.8.17;
import "src/products/externalInterfaces/IAaveV3LendingPool.sol";
import "oz/interfaces/IERC20.sol";
import { UD60x18 } from "@prb/math/UD60x18.sol";

/// @notice This Mock Aave pool can be used in 3 ways
/// - change the rate to a fixed value (`setReserveNormalizedIncome`)
/// - configure the rate to alter over time (`setFactorPerSecondInRay`) for more dynamic testing
contract MockAaveLendingPool is IAaveV3LendingPool {
    mapping(address => uint256) internal reserveNormalizedIncome;
    // mapping(IERC20 => uint256) internal reserveNormalizedVariableDebt;
    mapping(address => uint256) internal startTime;
    // mapping(IERC20 => uint256) internal factorPerSecondInRay; // E.g. 1000000001000000000000000000 for 0.0000001% per second = ~3.2% APY

    function getReserveNormalizedIncome(address _underlyingAsset)
        public
        view
        override
        returns (uint256)
    {
        // uint256 factorPerSecond = factorPerSecondInRay[_underlyingAsset];
        // if (factorPerSecond > 0) {
        //     uint256 secondsSinceNormalizedIncomeSet = block.timestamp -
        //         startTime[_underlyingAsset];
        //     return
        //         PRBMathUD60x18.mul(
        //             reserveNormalizedIncome[_underlyingAsset],
        //             PRBMathUD60x18.pow(
        //                 factorPerSecond,
        //                 secondsSinceNormalizedIncomeSet
        //             )
        //         );
        // } else {
            return reserveNormalizedIncome[_underlyingAsset];
        // }
    }

//     function getReserveNormalizedVariableDebt(IERC20 _underlyingAsset)
//         public
//         view
//         returns (uint256)
//     {
//         UD60x18 factorPerSecond = factorPerSecondInRay[_underlyingAsset];
//         if (factorPerSecond > 0) {
//             uint256 secondsSinceNormalizedVariableDebtSet = block.timestamp -
//                 startTime[_underlyingAsset];
//             return
//                 PRBMathUD60x18.mul(
//                     reserveNormalizedVariableDebt[_underlyingAsset],
//                     PRBMathUD60x18.pow(
//                         factorPerSecond,
//                         secondsSinceNormalizedVariableDebtSet
//                     )
//                 );
//         } else {
//             return reserveNormalizedVariableDebt[_underlyingAsset];
//         }
//     }

    function setReserveNormalizedIncome(
        IERC20 _underlyingAsset,
        uint256 _reserveNormalizedIncome
    ) public {
        reserveNormalizedIncome[address(_underlyingAsset)] = _reserveNormalizedIncome;
        startTime[address(_underlyingAsset)] = block.timestamp;
    }

//     function setReserveNormalizedVariableDebt(
//         IERC20 _underlyingAsset,
//         uint256 _reserveNormalizedVariableDebt
//     ) public {
//         reserveNormalizedVariableDebt[
//             _underlyingAsset
//         ] = _reserveNormalizedVariableDebt;
//         startTime[_underlyingAsset] = block.timestamp;
//     }

//     function setFactorPerSecondInRay(
//         IERC20 _underlyingAsset,
//         uint256 _factorPerSecondInRay
//     ) public {
//         factorPerSecondInRay[_underlyingAsset] = _factorPerSecondInRay;
//     }
}
