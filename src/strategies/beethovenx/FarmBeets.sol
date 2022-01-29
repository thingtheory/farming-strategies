// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../interfaces/beethovenx/IBeethovenxChef.sol";
import "../../interfaces/beethovenx/IBalancerVault.sol";
import "../../StratManager.sol";
import "../../FeeManager.sol";
import "../../interfaces/IStrategy.sol";
import "./BeethovenBaseStrat.sol";

contract FarmBeets is BeethovenBaseStrat {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    constructor(
        uint256 _basePID,
        address _underlying,
        address _chef,
        address _vault,
        address _balancerVault,
        address _beets
    ) BeethovenBaseStrat(_basePID, _underlying, _chef, _vault, _balancerVault, _beets) {
        giveAllowances();
    }

    // compounds earnings and charges performance fee
    function _harvest() internal override {
      uint256 balB4 = balanceOfWant();
      IBeethovenxChef(chef).harvest(basePID, address(this));
      uint256 outputBal = beets.balanceOf(address(this));
      if (outputBal > 0) {
        lastHarvest = block.timestamp;
        emit StratHarvest(msg.sender, balanceOfWant() - balB4, balanceOf());
      }
    }

    function giveAllowances() internal override {
        underlying.safeApprove(chef, 0);
        underlying.safeApprove(chef, type(uint256).max);
    }

    function removeAllowances() internal override {
        underlying.safeApprove(chef, 0);
    }
}
