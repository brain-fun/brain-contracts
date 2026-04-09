// SPDX-License-Identifier: MIT
// website: brain.fun
// twitter: x.com/braintao

//v2
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Token.sol";
import "./interfaces/IToken.sol";

contract BrainFactory is ReentrancyGuard {
    address public owner;

    uint256 public immutable virtualReserve;

    // Fee rates (immutable — no setter)
    uint256 public immutable totalFeeRate;
    uint256 public immutable deployerFeeRate;

    // Creator fee pool (pull pattern)
    mapping(address => uint256) public creatorBalances;
    uint256 public totalCreatorBalances;

    // Protocol fee pool (pull pattern) — H-02 FIX
    uint256 public protocolFeeBalance;

    // Token registry
    uint256 public tokenCount;
    mapping(uint256 => address) public tokenById;
    mapping(address => uint256) public tokenIdByAddress;
    mapping(address => uint256[]) public tokensByCreator;

    // Events
    event TokenCreated(
        uint256 indexed tokenId,
        address indexed tokenAddress,
        address indexed creator,
        string name,
        string symbol,
        string metadata,
        uint256 timestamp
    );
    event CreatorFeeDeposited(address indexed creator, address indexed token, uint256 amount);
    event CreatorFeeClaimed(address indexed creator, uint256 amount);
    event ProtocolFeeDeposited(address indexed token, uint256 amount);
    event ProtocolFeeClaimed(address indexed owner, uint256 amount);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        virtualReserve = 10 ether;
        totalFeeRate = 100;
        deployerFeeRate = 50;
    }

    // ──── Token Creation ────

    function createToken(
        string calldata _name,
        string calldata _symbol,
        string calldata _metadata
    ) external payable nonReentrant returns (uint256 tokenId, address tokenAddress) {
        require(bytes(_name).length > 0 && bytes(_name).length <= 32, "invalid name");
        require(bytes(_symbol).length > 0 && bytes(_symbol).length <= 10, "invalid symbol");

        tokenCount += 1;

        Token token = new Token(_name, _symbol, _metadata, msg.sender, address(this), virtualReserve);

        tokenById[tokenCount] = address(token);
        tokenIdByAddress[address(token)] = tokenCount;
        tokensByCreator[msg.sender].push(tokenCount);

        // Optional initial buy in the same tx (prevents frontrunning)
        if (msg.value > 0) {
            IToken(address(token)).buyFor{value: msg.value}(msg.sender, 0, block.timestamp);
        }

        emit TokenCreated(tokenCount, address(token), msg.sender, _name, _symbol, _metadata, block.timestamp);

        return (tokenCount, address(token));
    }

    // ──── Creator Fee Pool ────

    /// @notice Called by token contracts to deposit creator fees
    function depositCreatorFee(address _creator) external payable {
        require(tokenIdByAddress[msg.sender] > 0, "only tokens");
        creatorBalances[_creator] += msg.value;
        totalCreatorBalances += msg.value;
        emit CreatorFeeDeposited(_creator, msg.sender, msg.value);
    }

    /// @notice Allows creators to withdraw their accumulated fees
    function claimCreatorFees() external nonReentrant {
        uint256 amount = creatorBalances[msg.sender];
        require(amount > 0, "nothing to claim");
        // M-03 FIX: cap to actual balance (Bittensor ED may hide ~500 Gwei)
        if (amount > address(this).balance) {
            amount = address(this).balance;
        }
        creatorBalances[msg.sender] -= amount;
        totalCreatorBalances -= amount;
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "claim failed");
        emit CreatorFeeClaimed(msg.sender, amount);
    }

    // ──── Protocol Fee Pool (H-02 FIX) ────

    /// @notice Called by token contracts to deposit protocol fees
    function depositProtocolFee() external payable {
        require(tokenIdByAddress[msg.sender] > 0, "only tokens");
        protocolFeeBalance += msg.value;
        emit ProtocolFeeDeposited(msg.sender, msg.value);
    }

    /// @notice Allows owner to withdraw accumulated protocol fees
    function claimProtocolFees() external onlyOwner nonReentrant {
        uint256 amount = protocolFeeBalance;
        require(amount > 0, "nothing to claim");
        // M-03 FIX: cap to actual balance (Bittensor ED may hide ~500 Gwei)
        if (amount > address(this).balance) {
            amount = address(this).balance;
        }
        protocolFeeBalance -= amount;
        (bool success,) = payable(owner).call{value: amount}("");
        require(success, "claim failed");
        emit ProtocolFeeClaimed(owner, amount);
    }

    // ──── Rescue ────

    receive() external payable {}

    /// @notice Recovers accidentally sent TAO (excludes creator + protocol fee balances)
    function rescueTAO() external onlyOwner nonReentrant {
        uint256 reserved = totalCreatorBalances + protocolFeeBalance;
        require(address(this).balance > reserved, "nothing to rescue");
        uint256 rescuable = address(this).balance - reserved;
        (bool success,) = payable(owner).call{value: rescuable}("");
        require(success, "rescue failed");
    }

    // ──── View ────

    function getFees() external view returns (uint256, uint256) {
        return (totalFeeRate, deployerFeeRate);
    }

    function getCreatorBalance(address _creator) external view returns (uint256) {
        return creatorBalances[_creator];
    }

    function getTokenCount() external view returns (uint256) {
        return tokenCount;
    }

    function getToken(uint256 id) external view returns (address) {
        return tokenById[id];
    }

    function getTokenInfo(uint256 id)
        external
        view
        returns (
            address tokenAddress,
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
        )
    {
        tokenAddress = tokenById[id];
        require(tokenAddress != address(0), "token not found");
        (
            _name,
            _symbol,
            _metadata,
            _creator,
            _createdAt,
            _price,
            _virtualTaoReserve,
            _realTaoReserve,
            _tokenReserve,
            _totalVolumeTao,
            _totalTrades,
            _marketCap
        ) = IToken(tokenAddress).getTokenInfo();
    }

    function getTokens(uint256 offset, uint256 limit)
        external
        view
        returns (address[] memory tokenAddresses, uint256[] memory ids)
    {
        uint256 end = offset + limit;
        if (end > tokenCount) end = tokenCount;
        uint256 count = end > offset ? end - offset : 0;

        tokenAddresses = new address[](count);
        ids = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            uint256 id = offset + i + 1;
            ids[i] = id;
            tokenAddresses[i] = tokenById[id];
        }
    }

    function getTokensByCreator(address _creator) external view returns (uint256[] memory) {
        return tokensByCreator[_creator];
    }

    function getCreatorTokenCount(address _creator) external view returns (uint256) {
        return tokensByCreator[_creator].length;
    }

    // ──── Admin ────

function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
