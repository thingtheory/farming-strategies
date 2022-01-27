// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./SimpleVault.sol";
import "./strategies/beethovenx/RewardsToFBeets.sol";
import "./mocks/MockBalancerVault.sol";

contract SimpleVaultTest is DSTest {
  SimpleVault vault;

  function setUp() public {
    //bytes32[] memory poolID = new bytes32[](2);
    //poolID[0] = bytes32(0xc4dac57a46a0a1acd0eb95eddef5257926279960000200000000000000000150);
    //poolID[1] = bytes32(0xc4dac57a46a0a1acd0eb95eddef5257926279960000200000000000000000150);
    //address mc = address(0xBEEF03);

    //ERC20 tok = new ERC20("bar", "b");

    //address[] memory poolTokens = new address[](2);
    //poolTokens[0] = address(tok);
    //poolTokens[1] = address(0xBEEF04);

    //MockBalancerVault balVault = new MockBalancerVault();

    //vault = new SimpleVault("foobar", "fb", 0);
    ////RewardsToFBeets strat = new RewardsToFBeets(
    ////  poolID, 2, mc, address(vault), address(balVault)
    ////);

    //vault.initialize(mc);
  }

  function testFail_basic_sanity() public {
    assertTrue(false);
  }

  function test_basic_sanity() public {
    assertTrue(true);
  }
}
