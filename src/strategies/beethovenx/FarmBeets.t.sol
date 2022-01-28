// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "ds-test/test.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../SimpleVault.sol";
import "./FarmBeets.sol";
import "../../mocks/MockBalancerVault.sol";
import "../../mocks/MockMasterChef.sol";
import "../../mocks/MockERC20.sol";
import "../../mocks/MockBeetsBar.sol";
import "../../interfaces/IHevm.sol";

contract FarmBeetsTest is DSTest {
  FarmBeets strat;
  MockERC20 reward;
  MockERC20 tok;
  MockMasterChef chef;
  IHevm hevm;
  uint basePID;

  function setUp() public {
    bytes32[] memory poolID = new bytes32[](2);
    poolID[0] = bytes32(0xc4dac57a46a0a1acd0eb95eddef5257926279960000200000000000000000150);
    poolID[1] = bytes32(0xc4dac57a46a0a1acd0eb95eddef5257926279960000200000000000000000230);

    tok = new MockERC20("bar", "b");
    reward = new MockERC20("bar", "b");
    address[] memory chefTokens = new address[](1);
    chefTokens[0] = address(tok);
    chef = new MockMasterChef(chefTokens, address(reward));

    address[] memory poolTokens = new address[](1);
    poolTokens[0] = address(tok);

    MockBalancerVault balVault = new MockBalancerVault();
    balVault.setPoolTokens(poolID[0], poolTokens);
    balVault.setGetPool(poolID[0], address(tok));

    basePID = 0;
    SimpleVault vault = new SimpleVault("foobar", "fb", 0);
    strat = new FarmBeets(
      basePID, address(chef), address(this), address(balVault),
      address(reward), poolID[0]
    );

    hevm = IHevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    tok.mint(address(this), 1000 ether);
  }

  //function test_balanceOf() public {
  //  assertEq(address(strat.underlying()), address(tok));
  //  assertEq(strat.balanceOf(), 0);
  //  tok.approve(address(strat), type(uint256).max);
  //  tok.transfer(address(strat), 10 ether);
  //  assertEq(strat.balanceOf(), 10 ether);
  //  strat.deposit();
  //  assertEq(strat.balanceOf(), 10 ether);
  //}

  //function test_balanceOfWant() public {
  //  assertEq(address(strat.underlying()), address(tok));
  //  assertEq(strat.balanceOfWant(), 0);
  //  tok.approve(address(strat), type(uint256).max);
  //  tok.transfer(address(strat), 10 ether);
  //  assertEq(strat.balanceOfWant(), 0);

  //  strat.deposit();
  //  hevm.roll(block.number+5);

  //  strat.harvest();

  //  assertEq(strat.balanceOfWant(), 10 ether);
  //}

  //function test_withdraw() public {
  //  tok.approve(address(strat), type(uint256).max);
  //  strat.deposit();
  //  tok.transfer(address(strat), 10 ether);
  //  strat.deposit();

  //  hevm.roll(block.number+5);

  //  (uint bal, uint pending) = chef.userInfo(basePID, address(strat));
  //  assertGt(pending, 0);
  //  assertEq(bal, 10 ether);

  //  uint balB4 = tok.balanceOf(address(this));
  //  uint balB4Reward = reward.balanceOf(address(this));
  //  strat.withdraw(strat.balanceOf());
  //  assertEq(tok.balanceOf(address(this)) - balB4, 10 ether);
  //  (, pending) = chef.userInfo(basePID, address(strat));
  //  assertEq(pending, 0);
  //  assertEq(reward.balanceOf(address(this)) - balB4Reward, 0);
  //}

  //function test_deposit() public {
  //  tok.approve(address(strat), type(uint256).max);
  //  strat.deposit();
  //  uint balB4 = tok.balanceOf(address(strat));
  //  tok.transfer(address(strat), 10 ether);
  //  assertEq(tok.balanceOf(address(strat)) - balB4, 10 ether);
  //  balB4 = tok.balanceOf(address(chef));
  //  strat.deposit();
  //  assertEq(tok.balanceOf(address(strat)), 0);
  //  assertEq(tok.balanceOf(address(chef)) - balB4, 10 ether);
  //}

  function testFail_basic_sanity() public {
    assertTrue(false);
  }

  function test_basic_sanity() public {
    assertTrue(true);
  }
}

