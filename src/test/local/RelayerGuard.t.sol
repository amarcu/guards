// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import {DSTest} from "ds-test/test.sol";

import {DSToken} from "../utils/dapphub/DSToken.sol";
import {Hevm} from "../utils/Hevm.sol";

import {IRelayer} from "delphi/relayer/IRelayer.sol";
import {Relayer} from "delphi/relayer/Relayer.sol";
import {RelayerGuard} from "../../RelayerGuard.sol";

contract AerGuardTest is DSTest {
    Hevm hevm;

    Relayer relayer;
    RelayerGuard relayerGuard;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        relayer = new Relayer(
            address(0xC0111b005),
            IRelayer.RelayerType.DiscountRate,
            address(0x05Ac13),
            bytes32(uint256(1)),
            25
        );

        relayerGuard = new RelayerGuard(address(this), address(this), 1, address(relayer));
        relayer.allowCaller(relayer.ANY_SIG(), address(relayerGuard));
    }

    function try_call(address addr, bytes memory data) public returns (bool) {
        bytes memory _data = data;
        assembly {
            let ok := call(gas(), addr, 0, add(_data, 0x20), mload(_data), 0, 0)
            let free := mload(0x40)
            mstore(free, ok)
            mstore(0x40, add(free, 32))
            revert(free, 32)
        }
    }

    function can_call(address addr, bytes memory data) public returns (bool) {
        bytes memory call = abi.encodeWithSignature("try_call(address,bytes)", addr, data);
        (bool ok, bytes memory success) = address(this).call(call);
        ok = abi.decode(success, (bool));
        if (ok) return true;
        return false;
    }

    function test_isGuard() public {
        relayerGuard.isGuard();

        relayer.blockCaller(relayer.ANY_SIG(), address(relayerGuard));
        assertTrue(!can_call(address(relayerGuard), abi.encodeWithSelector(relayerGuard.isGuard.selector)));
    }

    
    function test_setMinimumPercentageDeltaValue() public {
        relayerGuard.setMinimumPercentageDeltaValue(0);
        relayerGuard.setMinimumPercentageDeltaValue(100_00);
        assertEq(relayer.minimumPercentageDeltaValue(), 100_00);

        assertTrue(
            !can_call(
                address(relayerGuard),
                abi.encodeWithSelector(relayerGuard.setMinimumPercentageDeltaValue.selector, 100_00 + 1)
            )
        );

        relayerGuard.setGuardian(address(0));
        assertTrue(
            !can_call(
                address(relayerGuard),
                abi.encodeWithSelector(relayerGuard.setMinimumPercentageDeltaValue.selector, 100_00)
            )
        );
    }
}
