// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { Base58Check } from "./Base58Check.sol";

/**
 * @title DogecoinAddress
 * @notice Never-reverting, network-aware validator for Dogecoin payout addresses. Dogecoin
 *         uses Base58Check only (no SegWit), so this validates legacy P2PKH and P2SH addresses on
 *         mainnet and testnet via the shared {Base58Check} core, differing from Bitcoin only in the
 *         version bytes.
 * @dev Mainnet: 0x1e P2PKH ("D..."), 0x16 P2SH ("9..."/"A..."). Testnet: 0x71 P2PKH, 0xc4 P2SH.
 *      Dogecoin has no on-address regtest distinction, so only mainnet/testnet are modelled.
 */
library DogecoinAddress {

    /**
     * @notice Returns true iff `_address` is a valid Dogecoin address for the requested network.
     * @dev Dogecoin has only mainnet and testnet (no SegWit, no regtest), so the network is a `bool`,
     *      matching {XrplAddress.isValid}. Never reverts.
     * @param _address  The address string to validate.
     * @param _testnet  True to require testnet, false to require mainnet.
     * @return          True iff `_address` is a well-formed Dogecoin P2PKH/P2SH address on the network.
     */
    function isValid(
        string memory _address,
        bool _testnet
    )
        internal view
        returns (bool)
    {
        (bool ok, uint8 version, ) = Base58Check.decode(_address);
        if (!ok) {
            return false;
        }
        if (version == 0x1e || version == 0x16) {
            return !_testnet; // mainnet P2PKH ("D...") / P2SH ("9.../A...")
        }
        if (version == 0x71 || version == 0xc4) {
            return _testnet; // testnet P2PKH / P2SH
        }
        return false;
    }
}
