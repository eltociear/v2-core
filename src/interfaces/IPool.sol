// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../utils/interfaces/IERC165.sol";

/// @title Interface a Product needs to adhere.
interface IPool is IERC165 {
    /// @notice returns a human-readable name for a given pool
    function name(uint128 poolId) external view returns (string memory);

    /// @dev note, a pool needs to have this interface to enable account closures initiated by products
    function executeDatedTakerOrder(uint128 marketId, uint256 maturityTimestamp, int256 baseAmount)
        external
        returns (int256 executedBaseAmount, int256 executedQuoteAmount);

    /// @dev note, pools that don't support perpetual products can just revert this function call
    function executePerpetualTakerOrder(uint128 marketId, int256 baseAmount)
        external
        returns (int256 executedBaseAmount, int256 executedQuoteAmount);
}
