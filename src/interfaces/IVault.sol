// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

import "./IStrategy.sol";

interface IVault is IERC20 {
    function deposit(uint256) external;
    function depositAll() external;
    function withdraw(uint256) external;
    function withdrawAll() external;
    function getPricePerFullShare() external view returns (uint256);
    function upgradeStrat() external;
    function balance() external view returns (uint256);
    function want() external view returns (IERC20);
    function strategy() external view returns (IStrategy);
}
