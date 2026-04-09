// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBrainFactory {
    function owner() external view returns (address);
    function getFees() external view returns (uint256 totalFeeRate, uint256 deployerFeeRate);
    function depositCreatorFee(address creator) external payable;
}
