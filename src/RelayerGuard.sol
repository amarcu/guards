// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import {Relayer} from "delphi/relayer/Relayer.sol";

import {BaseGuard} from "./BaseGuard.sol";

/// @title RelayerGuard
/// @notice Contract which guards parameter updates for a `Relayer`
contract RelayerGuard is BaseGuard {
    /// ======== Custom Errors ======== ///

    error RelayerGuard__isGuard_cantCall();

    /// ======== Storage ======== ///

    /// @notice Address of the Relayer
    Relayer public immutable relayer;

    constructor(
        address senatus,
        address guardian,
        uint256 delay,
        address relayer_
    ) BaseGuard(senatus, guardian, delay) {
        relayer = Relayer(relayer_);
    }

    /// @notice See `BaseGuard`
    function isGuard() external view override returns (bool) {
        if (!relayer.canCall(relayer.ANY_SIG(), address(this))) revert RelayerGuard__isGuard_cantCall();
        return true;
    }

    /// ======== Capabilities ======== ///

    /// @notice Sets the `minimumPercentageDeltaValue` parameter on the Relayer
    /// @dev Can only be called by the guardian. Checks if the value is in the allowed range.
    /// @param minimumPercentageDeltaValue See the Relayer contract
    function setMinimumPercentageDeltaValue(uint256 minimumPercentageDeltaValue) external isGuardian {
        _inRange(minimumPercentageDeltaValue, 0, 100_00);
        relayer.setParam("minimumPercentageDeltaValue", minimumPercentageDeltaValue);
    }
}
