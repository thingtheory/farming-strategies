pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStrategy {
    function underlying() external view returns (IERC20);
    function deposit() external;
    function withdraw(uint256) external;
    function balanceOf() external view returns (uint256);
    function balanceOfWant() external view returns (uint256);
    function balanceOfPool() external view returns (uint256);
    function harvest() external;
    function retireStrat() external;
    function panic() external;
    function pause() external;
    function unpause() external;
}

