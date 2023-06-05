pragma solidity >=0.8.19;

import { UD60x18 } from "@prb/math/UD60x18.sol";

/// @title Interface for the module for managing rate oracles connected to the Dated IRS Product
interface IRateOracleModule {
    /**
     * @notice Emitted when attempting to register a rate oracle with an invalid oracle address
     * @param oracleAddress Invalid oracle address
     */
    error InvalidVariableOracleAddress(address oracleAddress);
    /**
     * @notice Emitted when attempting to configure an unregistered oracle
     * @param oracleAddress Invalid oracle address
     */
    error UnknownVariableOracle(address oracleAddress);
    /**
     * @notice Emitted when attempting to register an already registered oracle
     * @param oracleAddress Invalid oracle address
     */
    error AlreadyRegisteredVariableOracle(address oracleAddress);

    /**
     * @notice Emitted when an oracle is configured for a market.
     * @param marketId The id of the market (e.g. aUSDC lend) associated with the rate oracle
     * @param oracleAddress Address of the variable rate oracle contract
     * @param blockTimestamp The current block timestamp.
     */
    event RateOracleConfigured(uint128 indexed marketId, address indexed oracleAddress, uint256 blockTimestamp);

    /**
     * @notice Requests a rate index snapshot at a maturity timestamp of a given interest rate market (e.g. aUSDC lend)
     * @param marketId Id of the market (e.g. aUSDC lend) for which we're requesting a rate index value
     * @param maturityTimestamp Maturity Timestamp of a given irs market that's requesting the index value for settlement purposes
     * @return rateIndexMaturity Rate index at the requested maturityTimestamp
     */
    function getRateIndexMaturity(uint128 marketId, uint32 maturityTimestamp) external returns (UD60x18 rateIndexMaturity);

    /**
     * @notice Requests the current rate index, or the index at maturity if we are past maturity, of a given interest rate market
     * (e.g. aUSDC borrow)
     * @param marketId Id of the market (e.g. aUSDC lend) for which we're requesting the current rate index value
     * @return rateIndexCurrent Rate index at the current timestamp or at maturity time (whichever comes earlier)
     */
    function getRateIndexCurrent(uint128 marketId, uint32 maturityTimestamp) external returns (UD60x18 rateIndexCurrent);

    /**
     * @notice Register a variable rate oralce
     * @param marketId Market Id
     * @param oracleAddress Oracle Address
     */
    function registerVariableOracle(uint128 marketId, address oracleAddress) external;

    /**
     * @notice Configure a variable rate oralce
     * @param marketId Market Id
     * @param oracleAddress Oracle Address
     */
    function configureVariableOracle(uint128 marketId, address oracleAddress) external;
}
