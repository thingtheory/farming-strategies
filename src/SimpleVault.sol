// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IVault.sol";
import "./interfaces/IStratManager.sol";

contract SimpleVault is IVault, ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct StratCandidate {
        address implementation;
        uint proposedTime;
    }

    StratCandidate public stratCandidate;
    IStrategy public override strategy;
    uint256 public immutable approvalDelay;

    event NewStratCandidate(address implementation);
    event UpgradeStrat(address implementation);

    constructor (
        string memory _name,
        string memory _symbol,
        uint256 _approvalDelay
    ) public ERC20(
        _name,
        _symbol
    ) {
        approvalDelay = _approvalDelay;
    }

    function initialize(address strategy_) external onlyOwner {
      strategy = IStrategy(strategy_);
    }

    function underlying() public view override returns (IERC20) {
        return IERC20(strategy.underlying());
    }

    function balance() public view override returns (uint) {
        return underlying().balanceOf(address(this)).add(IStrategy(strategy).balanceOf());
    }

    function available() public view returns (uint256) {
        return underlying().balanceOf(address(this));
    }

    function getPricePerFullShare() public view override returns (uint256) {
        return totalSupply() == 0 ? 1e18 : balance().mul(1e18).div(totalSupply());
    }

    function depositAll() external override {
        deposit(underlying().balanceOf(msg.sender));
    }

    function deposit(uint _amount) public override nonReentrant {
        IStratManager(address(strategy)).beforeDeposit();

        uint256 _pool = balance();
        underlying().safeTransferFrom(msg.sender, address(this), _amount);
        earn();
        uint256 _after = balance();
        _amount = _after.sub(_pool); // Additional check for deflationary tokens
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalSupply())).div(_pool);
        }
        _mint(msg.sender, shares);
    }

    function earn() public {
        uint _bal = available();
        underlying().safeTransfer(address(strategy), _bal);
        strategy.deposit();
    }

    function withdrawAll() external override {
        withdraw(balanceOf(msg.sender));
    }

    function withdraw(uint256 _shares) public override {
        uint256 r = (balance().mul(_shares)).div(totalSupply());
        _burn(msg.sender, _shares);

        uint b = underlying().balanceOf(address(this));
        if (b < r) {
            uint _withdraw = r.sub(b);
            strategy.withdraw(_withdraw);
            uint _after = underlying().balanceOf(address(this));
            uint _diff = _after.sub(b);
            if (_diff < _withdraw) {
                r = b.add(_diff);
            }
        }

        underlying().safeTransfer(msg.sender, r);
    }

    function proposeStrat(address _implementation) public onlyOwner {
        require(address(this) == IStratManager(_implementation).vault(), "Proposal not valid for this Vault");
        stratCandidate = StratCandidate({
            implementation: _implementation,
            proposedTime: block.timestamp
         });

        emit NewStratCandidate(_implementation);
    }

    function upgradeStrat() public override onlyOwner {
        require(stratCandidate.implementation != address(0), "There is no candidate");
        require(stratCandidate.proposedTime.add(approvalDelay) <= block.timestamp, "Delay has not passed");

        emit UpgradeStrat(stratCandidate.implementation);

        strategy.retireStrat();
        strategy = IStrategy(stratCandidate.implementation);
        stratCandidate.implementation = address(0);
        stratCandidate.proposedTime = 5000000000;

        earn();
    }

    function inCaseTokensGetStuck(address _token) external onlyOwner {
        require(_token != address(underlying()), "!token");

        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, amount);
    }
}
