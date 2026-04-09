// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IToken {
    function buyFor(address recipient, uint256 minTokensOut, uint256 deadline) external payable;
    function getTokenInfo() external view returns (
        string memory _name,
        string memory _symbol,
        string memory _metadata,
        address _creator,
        uint256 _createdAt,
        uint256 _price,
        uint256 _virtualTaoReserve,
        uint256 _realTaoReserve,
        uint256 _tokenReserve,
        uint256 _totalVolumeTao,
        uint256 _totalTrades,
        uint256 _marketCap
    );
}
