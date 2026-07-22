// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/**
 * @title MockSafe
 * @notice Minimal Safe multisig stand-in for tests: exposes `getOwners()`/`getThreshold()` and an
 *         `exec` passthrough so calls can be made with `msg.sender == address(this)`. The setters
 *         are deliberately unvalidated so tests can simulate owner rotation and malformed data
 *         (duplicate owners, zero address, zero/huge threshold).
 */
contract MockSafe {
    address[] internal owners;
    uint256 internal threshold;

    constructor(address[] memory _owners, uint256 _threshold) {
        owners = _owners;
        threshold = _threshold;
    }

    function setOwners(address[] memory _owners) external {
        owners = _owners;
    }

    function setThreshold(uint256 _threshold) external {
        threshold = _threshold;
    }

    function exec(address _target, bytes calldata _data) external returns (bytes memory) {
        (bool success, bytes memory result) = _target.call(_data);
        if (!success) {
            // Bubble up the revert reason.
            // solhint-disable-next-line no-inline-assembly
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        return result;
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getThreshold() external view returns (uint256) {
        return threshold;
    }

    function isOwner(address _owner) external view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _owner) {
                return true;
            }
        }
        return false;
    }
}
