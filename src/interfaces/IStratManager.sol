pragma solidity ^0.8.6;

interface IStratManager {
    function vault() external view returns (address);
    function unirouter() external view returns (address);
    function beforeDeposit() external;
}
