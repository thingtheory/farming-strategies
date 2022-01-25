// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./SimpleVault.sol";

contract SimpleVaultTest is DSTest {
    SimpleVault vault;

    function setUp() public {
        vault = new SimpleVault();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
