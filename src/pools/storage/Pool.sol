// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "../../utils/errors/AccessError.sol";
import "../../interfaces/IPool.sol";

/**
 * @title Connects external contracts that implement the `IPool` interface to the protocol.
 *
 */
library Pool {
    /**
     * @dev Thrown when a specified pool is not found.
     */
    error PoolNotFound(uint128 poolId);

    // todo: write up the reasons why we need this library at this stage

    struct Data {
        /**
         * @dev Numeric identifier for the pool. Must be unique.
         * @dev There cannot be a pool with id zero (See PoolCreator.create()). Id zero is used as a null pool reference.
         */
        uint128 id;
        /**
         * @dev Address for the external contract that implements the `IPool` interface, which this Pool objects connects to.
         *
         * Note: This object is how the system tracks the pool. The actual pool is external to the system, i.e. its own contract.
         */
        address poolAddress;
        /**
         * @dev Text identifier for the pool.
         *
         * Not required to be unique.
         */
        string name;
        /**
         * @dev Creator of the pool, which has configuration access rights for the pool.
         *
         * See onlyPoolOwner.
         */
        address owner;
    }

    /**
     * @dev Returns the pool stored at the specified pool id.
     */
    function load(uint128 id) internal pure returns (Data storage pool) {
        bytes32 s = keccak256(abi.encode("xyz.voltz.Pool", id));
        assembly {
            pool.slot := s
        }
    }

    /**
     * @dev Reverts if the caller is not the owner of the specified pool
     */
    function onlyPoolOwner(uint128 poolId, address caller) internal view {
        if (Pool.load(poolId).owner != caller) {
            revert AccessError.Unauthorized(caller);
        }
    }
}
