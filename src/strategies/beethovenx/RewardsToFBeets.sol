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

contract RewardsToFBeets is IStrategy, Ownable, Pausable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Tokens used
    IERC20 public override underlying;
    IERC20 public beets;
    IERC20 public fBeetsBPT;

    // Third party contracts
    address public chef;
    address public vault;
    address public balancerVault;

    // Masterchef
    uint256 public basePID;
    uint256 public fBeetsPID;

    // Beethoven-X
    IBalancerVault.SwapKind public swapKind;
    IBalancerVault.FundManagement public funds;
    bytes32 public fBeetsPoolID;
    bytes32 public underlyingPoolID;
    address[] public lpTokens;

    bool public harvestOnDeposit;
    uint256 public lastHarvest;

    event StratHarvest(address indexed harvester, uint256 underlyingHarvested, uint256 tvl);
    event Deposit(uint256 tvl);
    event Withdraw(uint256 tvl);

    constructor(
        uint256 _basePID,
        uint256 _fBeetsPID,
        address _chef,
        address _vault,
        address _balancerVault,
        address _beets,
        bytes32 _underlyingPoolID,
        bytes32 _fBeetsPoolID
    ) {
        underlyingPoolID = _underlyingPoolID;
        fBeetsPoolID = _fBeetsPoolID;
        basePID = _basePID;
        fBeetsPID = _fBeetsPID;
        chef = _chef;
        vault = _vault;
        balancerVault = _balancerVault;

        (address underlying_,) = IBalancerVault(balancerVault).getPool(underlyingPoolID);
        underlying = IERC20(underlying_);
        (address fBeetsBPT_,) = IBalancerVault(balancerVault).getPool(fBeetsPoolID);
        fBeetsBPT = IERC20(fBeetsBPT_);
        beets = IERC20(_beets);


        (lpTokens,,) = IBalancerVault(balancerVault).getPoolTokens(underlyingPoolID);
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
        (uint256 amount, ) = IBeethovenxChef(chef).userInfo(fBeetsPID, address(this));
        return fBeetsBPT.balanceOf(address(this)) + amount;
    }

    function balanceOfUnderlying() public view returns (uint256) {
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

    // called as part of strat migration. Sends all the available funds back to the vault.
    function retireStrat() external override {
        require(msg.sender == vault, "!vault");

        IBeethovenxChef(chef).emergencyWithdraw(basePID, address(this));

        uint256 underlyingBal = underlying.balanceOf(address(this));
        underlying.transfer(vault, underlyingBal);
    }

    function harvest() external virtual override whenNotPaused {
        _harvest();
    }

    // compounds earnings and charges performance fee
    function _harvest() internal {
      uint256 balB4 = fBEETSBalance();
      IBeethovenxChef(chef).harvest(basePID, address(this));
      IBeethovenxChef(chef).harvest(fBeetsPID, address(this));
      uint256 outputBal = beets.balanceOf(address(this));
      if (outputBal > 0) {
        depositToFBeets(outputBal);

        lastHarvest = block.timestamp;
        emit StratHarvest(msg.sender, fBEETSBalance() - balB4, balanceOf());
      }
    }

    function fBEETSBalance() internal view returns(uint256) {
      (uint256 bal, ) = IBeethovenxChef(chef).userInfo(fBeetsPID, address(this));
      return bal;
    }

    function depositToFBeets(uint256 beetsAmt) internal {
      balancerJoin(fBeetsPoolID, address(beets), beetsAmt);
      IBeethovenxChef(chef).deposit(fBeetsPID, fBeetsBPT.balanceOf(address(this)), address(this));
    }

    function giveAllowances() internal {
        underlying.safeApprove(chef, 0);
        underlying.safeApprove(chef, type(uint256).max);
        fBeetsBPT.safeApprove(chef, 0);
        fBeetsBPT.safeApprove(chef, type(uint256).max);
        beets.safeApprove(balancerVault, 0);
        beets.safeApprove(balancerVault, type(uint256).max);
    }

    function removeAllowances() internal {
        underlying.safeApprove(chef, 0);
        fBeetsBPT.safeApprove(chef, 0);
        beets.safeApprove(balancerVault, 0);
    }

    function balancerJoin(bytes32 _poolId, address _tokenIn, uint256 _amountIn) internal {
        uint256[] memory amounts = new uint256[](lpTokens.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            amounts[i] = lpTokens[i] == _tokenIn ? _amountIn : 0;
        }
        bytes memory userData = abi.encode(1, amounts, 1); // TODO

        IBalancerVault.JoinPoolRequest memory request = IBalancerVault.JoinPoolRequest(lpTokens, amounts, userData, false);
        IBalancerVault(balancerVault).joinPool(_poolId, address(this), address(this), request);
    }

}
