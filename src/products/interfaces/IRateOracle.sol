// SPDX-License-Identifier: Apache-2.0

pragma solidity =0.8.17;

/// @dev The RateOracle is used for two purposes on the Voltz Protocol
/// @dev Settlement: in order to be able to settle IRS positions after the termEndTimestamp of a given AMM
/// @dev Margin Engine Computations: getApyFromTo is used by the MarginEngine
/// @dev It is necessary to produce margin requirements for Trader and Liquidity Providers
interface IRateOracle {

    /// @notice Get the last updated rate in Ray with the accompanying truncated timestamp
    /// This data point must be a known data point from the source of the data, and not extrapolated or interpolated by us.
    /// The source and expected values of "rate" may differ by rate oracle type. All that
    /// matters is that we can divide one "rate" by another "rate" to get the factor of growth between the two timestamps.
    /// For example if we have rates of { (t=0, rate=5), (t=100, rate=5.5) }, we can divide 5.5 by 5 to get a growth factor
    /// of 1.1, suggesting that 10% growth in capital was experienced between timesamp 0 and timestamp 100.
    /// @dev FOr convenience, the rate is normalised to Ray for storage, so that we can perform consistent math across all rates.
    /// @dev This function should revert if a valid rate cannot be discerned
    /// @return timestamp the timestamp corresponding to the known rate (could be the current time, or a time in the past)
    /// @return resultRay the rate in Ray (decimal scaled up by 10^27 for storage in a uint256)
    function getCurrentLiquidityIndex()
        external
        view
        returns (uint40 timestamp, uint256 resultRay);
}