// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "./SimpleVault.sol";
import "./strategies/beethovenx/RewardsToFBeets.sol";

contract SimpleVaultTest is DSTest {
  SimpleVault vault;

  function setUp() public {
    bytes32[] memory poolID = new bytes32[](2);
    RewardsToFBeets strat = new RewardsToFBeets(
      poolID, 2, address(this), address(this), address(this), address(this), address(this), address(this), address(this));
    vault = new SimpleVault(IStrategy(address(strat)), "foobar", "fb", 0);
  }

  function testFail_basic_sanity() public {
    assertTrue(false);
  }

  function test_basic_sanity() public {
    assertTrue(true);
  }
}
