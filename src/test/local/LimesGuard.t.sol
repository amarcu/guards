// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import {DSTest} from "ds-test/test.sol";

import {DSToken} from "../utils/dapphub/DSToken.sol";
import {Hevm} from "../utils/Hevm.sol";

import {Codex} from "fiat/Codex.sol";
import {Limes} from "fiat/Limes.sol";

import {WAD} from "fiat/utils/Math.sol";
import {LimesGuard} from "../../LimesGuard.sol";

contract AerGuardTest is DSTest {
    Hevm hevm;

    Codex codex;
    Limes limes;
    LimesGuard limesGuard;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        codex = new Codex();
        limes = new Limes(address(codex));

        limesGuard = new LimesGuard(address(this), address(this), 1, address(limes));
        limes.allowCaller(limes.ANY_SIG(), address(limesGuard));
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
        limesGuard.isGuard();

        limes.blockCaller(limes.ANY_SIG(), address(limesGuard));
        assertTrue(!can_call(address(limesGuard), abi.encodeWithSelector(limesGuard.isGuard.selector)));
    }

    function test_setAer() public {
        assertTrue(!can_call(address(limesGuard), abi.encodeWithSelector(limesGuard.setAer.selector, address(1))));

        bytes memory call = abi.encodeWithSelector(limesGuard.setAer.selector, address(1));
        limesGuard.schedule(call);

        assertTrue(
            !can_call(
                address(limesGuard),
                abi.encodeWithSelector(
                    limesGuard.execute.selector,
                    address(limesGuard),
                    call,
                    block.timestamp + limesGuard.delay()
                )
            )
        );

        hevm.warp(block.timestamp + limesGuard.delay());
        limesGuard.execute(address(limesGuard), call, block.timestamp);
        assertEq(address(limes.aer()), address(1));
    }

    function test_setGlobalMaxDebtOnAuction() public {
        limesGuard.setGlobalMaxDebtOnAuction(0);
        limesGuard.setGlobalMaxDebtOnAuction(10_000_000 * WAD);
        assertEq(limes.globalMaxDebtOnAuction(), 10_000_000 * WAD);

        assertTrue(
            !can_call(
                address(limesGuard),
                abi.encodeWithSelector(limesGuard.setGlobalMaxDebtOnAuction.selector, 10_000_000 * WAD + 1)
            )
        );

        limesGuard.setGuardian(address(0));
        assertTrue(
            !can_call(
                address(limesGuard),
                abi.encodeWithSelector(limesGuard.setGlobalMaxDebtOnAuction.selector, 10_000_000 * WAD)
            )
        );
    }

    function test_setLiquidationPenalty() public {
        limesGuard.setLiquidationPenalty(address(1), WAD);
        limesGuard.setLiquidationPenalty(address(1), 2 * WAD);
        (, uint256 liquidationPenalty, , ) = limes.vaults(address(1));
        assertEq(liquidationPenalty, 2 * WAD);

        assertTrue(
            !can_call(
                address(limesGuard),
                abi.encodeWithSelector(limesGuard.setLiquidationPenalty.selector, address(1), 2 * WAD + 1)
            )
        );

        limesGuard.setGuardian(address(0));
        assertTrue(
            !can_call(
                address(limesGuard),
                abi.encodeWithSelector(limesGuard.setLiquidationPenalty.selector, address(1), 2 * WAD)
            )
        );
    }

    function test_setMaxDebtOnAuction() public {
        limesGuard.setMaxDebtOnAuction(address(1), 0);
        limesGuard.setMaxDebtOnAuction(address(1), 5_000_000 * WAD);
        (, , uint256 maxDebtOnAuction, ) = limes.vaults(address(1));
        assertEq(maxDebtOnAuction, 5_000_000 * WAD);

        assertTrue(
            !can_call(
                address(limesGuard),
                abi.encodeWithSelector(limesGuard.setMaxDebtOnAuction.selector, address(1), 5_000_000 * WAD + 1)
            )
        );

        limesGuard.setGuardian(address(0));
        assertTrue(
            !can_call(
                address(limesGuard),
                abi.encodeWithSelector(limesGuard.setMaxDebtOnAuction.selector, address(1), 5_000_000 * WAD)
            )
        );
    }

    function test_setCollateralAuction() public {
        assertTrue(
            !can_call(
                address(limesGuard),
                abi.encodeWithSelector(limesGuard.setCollateralAuction.selector, address(1), address(1))
            )
        );

        bytes memory call = abi.encodeWithSelector(limesGuard.setCollateralAuction.selector, address(1), address(1));
        limesGuard.schedule(call);

        assertTrue(
            !can_call(
                address(limesGuard),
                abi.encodeWithSelector(
                    limesGuard.execute.selector,
                    address(limesGuard),
                    call,
                    block.timestamp + limesGuard.delay()
                )
            )
        );

        hevm.warp(block.timestamp + limesGuard.delay());
        limesGuard.execute(address(limesGuard), call, block.timestamp);

        (address collateralAuction, , , ) = limes.vaults(address(1));
        assertEq(collateralAuction, address(1));
    }
}
