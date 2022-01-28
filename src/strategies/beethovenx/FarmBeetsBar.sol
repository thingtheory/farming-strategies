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
import "../../interfaces/beethovenx/IBeetsBar.sol";
import "./BeethovenBaseStrat.sol";

contract FarmBeetsBar is BeethovenBaseStrat {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Tokens used
    IERC20 public fBeetsBPT;

    // Beethoven-X
    bytes32 public fBeetsPoolID;
    //address[] public lpTokens;

    constructor(
        uint256 _basePID,
        address _underlying,
        address _chef,
        address _vault,
        address _balancerVault,
        address _beets,
        bytes32 _fBeetsPoolID
    ) BeethovenBaseStrat(_basePID, _underlying, _chef, _vault, _balancerVault, _beets, _fBeetsPoolID) {
        fBeetsPoolID = _fBeetsPoolID;

        (address fBeetsBPT_,) = IBalancerVault(balancerVault).getPool(fBeetsPoolID);
        fBeetsBPT = IERC20(fBeetsBPT_);

        (lpTokens,,) = IBalancerVault(balancerVault).getPoolTokens(fBeetsPoolID);
        swapKind = IBalancerVault.SwapKind.GIVEN_IN;
        funds = IBalancerVault.FundManagement(address(this), false, payable(address(this)), false);

        giveAllowances();
    }

    // calculate the total 'underlying' held by the strat.
    function balanceOf() public view override returns (uint256) {
        return balanceOfUnderlying().add(balanceOfPool());
    }

    // calculate how much 'want' this contract holds.
    function balanceOfWant() public view override returns (uint256) {
      return balanceOfUnderlying();
    }

    function balanceOfUnderlying() public view override returns (uint256) {
        return underlying.balanceOf(address(this));
    }

    // calculate how much 'underlying' the strategy has working in the farm.
    function balanceOfPool() public view override returns (uint256) {
        (uint256 _amount,) = IBeethovenxChef(chef).userInfo(basePID, address(this));
        return _amount;
    }

    function pause() public override onlyOwner {
        _pause();

        removeAllowances();
    }

    // pauses deposits and withdraws all funds from third party systems.
    function panic() external override onlyOwner {
        pause();
        IBeethovenxChef(chef).emergencyWithdraw(basePID, address(this));
    }

    function unpause() external override onlyOwner {
        _unpause();

        giveAllowances();

        deposit();
    }

    // puts the funds to work
    function deposit() public override whenNotPaused {
        require(msg.sender == vault, "!vault");

        uint256 underlyingBal = underlying.balanceOf(address(this));

        if (underlyingBal > 0) {
            IBeethovenxChef(chef).deposit(basePID, underlyingBal, address(this));
            emit Deposit(balanceOf());
        }
    }

    function withdraw(uint256 _amount) external override {
        require(msg.sender == vault, "!vault");

        uint256 underlyingBal = underlying.balanceOf(address(this));

        if (underlyingBal < _amount) {
            IBeethovenxChef(chef).withdrawAndHarvest(basePID, _amount.sub(underlyingBal), address(this));
            underlyingBal = underlying.balanceOf(address(this));
        }

        if (underlyingBal > _amount) {
            underlyingBal = _amount;
        }

        underlying.safeTransfer(vault, underlyingBal);

        emit Withdraw(balanceOf());
    }

    function withdrawReward(uint256 _amount) external override {
        require(msg.sender == vault, "!vault");

        uint256 beetsBal = beets.balanceOf(address(this));

        if (beetsBal < _amount) {
            _harvest();
            beetsBal = beets.balanceOf(address(this));
        }

        if (beetsBal > _amount) {
            beetsBal = _amount;
        }

        beets.safeTransfer(vault, beetsBal);

        emit WithdrawReward(beetsBal);
    }

    // called as part of strat migration. Sends all the available funds back to the vault.
    function retireStrat() external override {
        require(msg.sender == vault, "!vault");

        IBeethovenxChef(chef).emergencyWithdraw(basePID, address(this));

        uint256 underlyingBal = underlying.balanceOf(address(this));
        underlying.transfer(vault, underlyingBal);
    }

    // compounds earnings and charges performance fee
    function _harvest() internal override {
      uint256 balB4 = balanceOf();
      IBeethovenxChef(chef).harvest(basePID, address(this));
      uint256 outputBal = beets.balanceOf(address(this));
      if (outputBal > 0) {
        depositToFBeets(outputBal);

        lastHarvest = block.timestamp;
        uint256 balAfter = balanceOf();
        emit StratHarvest(msg.sender, balAfter - balB4, balAfter);
      }
    }

    function depositToFBeets(uint256 beetsAmt) internal {
      balancerJoin(fBeetsPoolID, address(beets), beetsAmt);
      IBeetsBar(address(underlying)).enter(fBeetsBPT.balanceOf(address(this)));
      IBeethovenxChef(chef).deposit(basePID, balanceOfWant(), address(this));
    }

    function giveAllowances() internal override {
        underlying.safeApprove(chef, 0);
        underlying.safeApprove(chef, type(uint256).max);
        beets.safeApprove(balancerVault, 0);
        beets.safeApprove(balancerVault, type(uint256).max);
        fBeetsBPT.safeApprove(address(underlying), 0);
        fBeetsBPT.safeApprove(address(underlying), type(uint256).max);
    }

    function removeAllowances() internal override {
        underlying.safeApprove(chef, 0);
        beets.safeApprove(balancerVault, 0);
        fBeetsBPT.safeApprove(address(underlying), 0);
    }

    function balancerJoin(bytes32 _poolId, address _tokenIn, uint256 _amountIn) internal override {
        uint256[] memory amounts = new uint256[](lpTokens.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            amounts[i] = lpTokens[i] == _tokenIn ? _amountIn : 0;
        }
        bytes memory userData = abi.encode(1, amounts, 1); // TODO

        IBalancerVault.JoinPoolRequest memory request = IBalancerVault.JoinPoolRequest(lpTokens, amounts, userData, false);
        IBalancerVault(balancerVault).joinPool(_poolId, address(this), address(this), request);
    }

}

