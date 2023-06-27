/*
Licensed under the Voltz v2 License (the "License"); you
may not use this file except in compliance with the License.
You may obtain a copy of the License at

https://github.com/Voltz-Protocol/v2-core/blob/main/products/dated-irs/LICENSE
*/
pragma solidity >=0.8.19;

import "../interfaces/IRateOracle.sol";
import "../interfaces/external/IAaveV3LendingPool.sol";
import "@voltz-protocol/util-contracts/src/helpers/Time.sol";
import { UD60x18, ud, unwrap } from "@prb/math/UD60x18.sol";

contract AaveV3BorrowRateOracle is IRateOracle {
    IAaveV3LendingPool public aaveLendingPool;
    address public immutable underlying;

    constructor(IAaveV3LendingPool _aaveLendingPool, address _underlying) {
        // todo: introduce custom error
        require(address(_aaveLendingPool) != address(0), "aave pool must exist");

        underlying = _underlying;
        aaveLendingPool = _aaveLendingPool;
    }

    /// @inheritdoc IRateOracle
    function getLastUpdatedIndex() public view override returns (uint32 timestamp, UD60x18 liquidityIndex) {
        uint256 liquidityIndexInRay = aaveLendingPool.getReserveNormalizedVariableDebt(underlying);
        return (Time.blockTimestampTruncated(), ud(liquidityIndexInRay / 1e9));
    }

    /// @inheritdoc IRateOracle
    function getCurrentIndex() external view override returns (UD60x18 liquidityIndex) {
        uint256 liquidityIndexInRay = aaveLendingPool.getReserveNormalizedVariableDebt(underlying);
        // Convert index from Aave's "ray" (decimal scaled by 10^27) to UD60x18 (decimal scaled by 10^18)
        return ud(liquidityIndexInRay / 1e9);
    }

    /// @inheritdoc IRateOracle
    function interpolateIndexValue(
        UD60x18 beforeIndex,
        uint256 beforeTimestampWad,
        UD60x18 atOrAfterIndex,
        uint256 atOrAfterTimestampWad,
        uint256 queryTimestampWad
    )
    public
    pure
    returns (UD60x18 interpolatedIndex)
    {
        // todo: consider pushing this function into a shared stateless library
        require(queryTimestampWad > beforeTimestampWad, "Unordered timestamps");

        if (atOrAfterTimestampWad == queryTimestampWad) {
            return atOrAfterIndex;
        }

        require(queryTimestampWad < atOrAfterTimestampWad, "Unordered timestamps");

        // TODO: fix calculation to account for compounding (is there a better way than calculating an APY and applying it?)
        UD60x18 totalDelta = atOrAfterIndex.sub(beforeIndex); // this does not allow negative rates

        UD60x18 proportionOfPeriodElapsed =
        ud(queryTimestampWad - beforeTimestampWad).div(ud(atOrAfterTimestampWad - beforeTimestampWad));
        return proportionOfPeriodElapsed.mul(totalDelta).add(beforeIndex);
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) external view override(IERC165) returns (bool) {
        return interfaceId == type(IRateOracle).interfaceId || interfaceId == this.supportsInterface.selector;
    }
}