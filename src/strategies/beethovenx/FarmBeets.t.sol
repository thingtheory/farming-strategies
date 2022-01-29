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

contract TestCallerFarmBeets {
  FarmBeets strat;

  constructor(address _strat) public {
    strat = FarmBeets(_strat);
  }

  function deposit() public {
    strat.deposit();
  }

  function withdraw(uint256 amount) public {
    strat.withdraw(amount);
  }

  function withdrawReward(uint256 amount) public {
    strat.withdrawReward(amount);
  }

  function harvest() public {
    strat.harvest();
  }
}

contract FarmBeetsTest is DSTest {
  FarmBeets strat;
  MockERC20 reward;
  MockERC20 underlying;
  MockMasterChef chef;
  IHevm hevm;
  uint basePID;

  function setUp() public {
    bytes32[] memory poolID = new bytes32[](2);
    poolID[0] = bytes32(0xc4dac57a46a0a1acd0eb95eddef5257926279960000200000000000000000150);
    poolID[1] = bytes32(0xc4dac57a46a0a1acd0eb95eddef5257926279960000200000000000000000230);

    underlying = new MockERC20("bar", "b");
    reward = new MockERC20("bar", "b");

    address[] memory chefTokens = new address[](1);
    chefTokens[0] = address(underlying);
    chef = new MockMasterChef(chefTokens, address(reward));


    address[] memory poolTokens = new address[](1);
    poolTokens[0] = address(underlying);

    MockBalancerVault balVault = new MockBalancerVault();
    balVault.setPoolTokens(poolID[0], poolTokens);
    balVault.setGetPool(poolID[0], address(underlying));

    basePID = 0;
    strat = new FarmBeets(
      basePID, address(underlying), address(chef), address(this), address(balVault),
      address(reward)
    );

    hevm = IHevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    underlying.mint(address(this), 1000 ether);
  }

  function test_permissions() public {
    TestCallerFarmBeets caller = new TestCallerFarmBeets(address(strat));
    underlying.transfer(address(strat), 10 ether);
    try caller.deposit() {
      revert("expected deposit to fail");
    } catch {
    }
    try caller.withdraw(10 ether) {
      revert("expected withdraw to fail");
    } catch {
    }
    try caller.withdrawReward(10 ether) {
      revert("expected withdrawReward to fail");
    } catch {
    }
    strat.harvest();
    caller.harvest();
  }

  function test_balanceOf() public {
    assertEq(address(strat.underlying()), address(underlying));
    // before any deposits the balance is 0
    assertEq(strat.balanceOf(), 0);
    underlying.approve(address(strat), type(uint256).max);
    underlying.transfer(address(strat), 10 ether);
    // if the strat holds the balance it is returned
    assertEq(strat.balanceOf(), 10 ether);
    strat.deposit();
    // if the masterchef holds the balance it is returned
    assertEq(strat.balanceOf(), 10 ether);
  }

  function test_withdraw() public {
    underlying.approve(address(strat), type(uint256).max);
    strat.deposit();
    underlying.transfer(address(strat), 10 ether);
    strat.deposit();

    hevm.roll(block.number+5);

    (uint bal, uint pending) = chef.userInfo(basePID, address(strat));
    assertGt(pending, 0);
    assertEq(bal, 10 ether);

    uint balB4 = underlying.balanceOf(address(this));
    strat.withdraw(strat.balanceOf());
    // it transfers the balance of the vault
    assertEq(underlying.balanceOf(address(this)) - balB4, 10 ether);
    (, pending) = chef.userInfo(basePID, address(strat));
    // it claims any pending rewards
    assertEq(pending, 0);
  }

  function test_withdraw_existing_balance() public {
    underlying.approve(address(strat), type(uint256).max);
    underlying.transfer(address(strat), 10 ether);
    uint balB4 = underlying.balanceOf(address(this));
    strat.deposit();
    hevm.roll(block.number+5);

    (uint bal, uint pending) = chef.userInfo(basePID, address(strat));
    assertGt(pending, 0);
    assertEq(bal, 10 ether);
    underlying.transfer(address(strat), 10 ether);
    strat.withdraw(10 ether);
    (uint balAfter, uint pendingAfter) = chef.userInfo(basePID, address(strat));
    // it withdraws the requested amount of underlying
    assertEq(bal, balAfter);
    // it only withdraws/harvests from the masterchef if needed
    assertEq(pending, pendingAfter);
  }

  function test_withdrawReward() public {
    underlying.approve(address(strat), type(uint256).max);
    strat.deposit();
    underlying.transfer(address(strat), 10 ether);
    strat.deposit();

    hevm.roll(block.number+5);

    (uint bal, uint pending) = chef.userInfo(basePID, address(strat));
    assertGt(pending, 0);
    assertEq(bal, 10 ether);

    strat.withdrawReward(pending);
    // it transfers the reward to the vault
    assertEq(reward.balanceOf(address(this)), pending);
    (, pending) = chef.userInfo(basePID, address(strat));
    // it claims any pending rewards
    assertEq(pending, 0);
  }

  function test_deposit() public {
    underlying.approve(address(strat), type(uint256).max);
    strat.deposit();
    uint balB4 = underlying.balanceOf(address(strat));
    underlying.transfer(address(strat), 10 ether);
    assertEq(underlying.balanceOf(address(strat)) - balB4, 10 ether);
    balB4 = underlying.balanceOf(address(chef));
    strat.deposit();
    // it deposits the funds into the masterchef
    assertEq(underlying.balanceOf(address(strat)), 0);
    assertEq(underlying.balanceOf(address(chef)) - balB4, 10 ether);
  }

  function test_harvest() public {
    underlying.approve(address(strat), type(uint256).max);
    strat.deposit();
    underlying.transfer(address(strat), 10 ether);
    strat.deposit();

    hevm.roll(block.number+5);

    (uint balB4, uint pendingB4) = chef.userInfo(basePID, address(strat));
    assertGt(pendingB4, 0);

    strat.harvest();

    (uint bal, uint pending) = chef.userInfo(basePID, address(strat));
    // it compounds the rewards into more underlying
    assertEq(bal, balB4);
    // it harvests any pending rewards
    assertEq(pending, 0);
    assertEq(reward.balanceOf(address(strat)), 50 ether);
  }

  function testFail_basic_sanity() public {
    assertTrue(false);
  }

  function test_basic_sanity() public {
    assertTrue(true);
  }
}


