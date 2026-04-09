// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IBrainFactory.sol";

contract Token is ReentrancyGuard {
    // Constants
    uint8 public constant decimals = 18;
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;
    uint256 public constant FEE_DENOMINATOR = 10000;

    // ERC-20
    string public name;
    string public symbol;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Metadata
    string public metadata;
    address public immutable creator;
    uint256 public immutable createdAt;

    // AMM reserves
    uint256 public immutable virtualTaoReserve;
    uint256 public realTaoReserve;
    uint256 public tokenReserve;

    // Factory reference
    address public immutable factory;

    // Stats
    uint256 public totalVolumeTao;
    uint256 public totalTrades;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Buy(
        address indexed buyer,
        uint256 taoIn,
        uint256 tokensOut,
        uint256 price,
        uint256 realTaoReserveAfter,
        uint256 tokenReserveAfter,
        uint256 timestamp
    );
    event Sell(
        address indexed seller,
        uint256 tokensIn,
        uint256 taoOut,
        uint256 price,
        uint256 realTaoReserveAfter,
        uint256 tokenReserveAfter,
        uint256 timestamp
    );

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _metadata,
        address _creator,
        address _factory,
        uint256 _virtualTaoReserve
    ) {
        require(_virtualTaoReserve > 0, "virtual reserve must be > 0");
        name = _name;
        symbol = _symbol;
        metadata = _metadata;
        creator = _creator;
        createdAt = block.timestamp;
        factory = _factory;
        virtualTaoReserve = _virtualTaoReserve;

        totalSupply = TOTAL_SUPPLY;
        tokenReserve = TOTAL_SUPPLY;
        balanceOf[address(this)] = TOTAL_SUPPLY;

        emit Transfer(address(0), address(this), TOTAL_SUPPLY);
    }

    // ──── ERC-20 ────

    function transfer(address to, uint256 amount) external returns (bool) {
        require(to != address(0), "transfer to zero");
        require(to != address(this), "transfer to token");
        require(balanceOf[msg.sender] >= amount, "insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        allowance[msg.sender][spender] += addedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 current = allowance[msg.sender][spender];
        require(current >= subtractedValue, "decreased below zero");
        allowance[msg.sender][spender] = current - subtractedValue;
        emit Approval(msg.sender, spender, allowance[msg.sender][spender]);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(to != address(0), "transfer to zero");
        require(to != address(this), "transfer to token");
        require(allowance[from][msg.sender] >= amount, "insufficient allowance");
        require(balanceOf[from] >= amount, "insufficient balance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // ──── AMM ────

    function buy(uint256 minTokensOut, uint256 deadline) external payable nonReentrant {
        _buy(msg.sender, minTokensOut, deadline);
    }

    /// @notice Allows the factory to execute a buy on behalf of a recipient (used for initial buy on token creation)
    function buyFor(address recipient, uint256 minTokensOut, uint256 deadline) external payable nonReentrant {
        require(msg.sender == factory, "only factory");
        _buy(recipient, minTokensOut, deadline);
    }

    function _buy(address recipient, uint256 minTokensOut, uint256 deadline) internal {
        require(msg.value > 0, "zero value");
        require(block.timestamp <= deadline, "expired");

        // Fetch fee rates from factory — single-step calculation for precision
        (uint256 feeRate, uint256 deployerRate) = IBrainFactory(factory).getFees();
        uint256 totalFee;
        uint256 deployerFee;
        uint256 protocolFee;

        if (feeRate > 0) {
            totalFee = msg.value * feeRate / FEE_DENOMINATOR;
            deployerFee = msg.value * deployerRate / FEE_DENOMINATOR;
            protocolFee = totalFee - deployerFee;
        }

        uint256 netTaoIn = msg.value - totalFee;

        // Constant product AMM: x * y = k
        // Round newTokenReserve UP → trader gets fewer tokens → k never decreases
        uint256 effectiveTao = virtualTaoReserve + realTaoReserve;
        uint256 k = effectiveTao * tokenReserve;
        uint256 newEffectiveTao = effectiveTao + netTaoIn;
        uint256 newTokenReserve = (k + newEffectiveTao - 1) / newEffectiveTao;
        uint256 tokensOut = tokenReserve - newTokenReserve;

        require(tokensOut > 0, "output too small");
        require(tokensOut >= minTokensOut, "slippage");

        // Update state
        realTaoReserve += netTaoIn;
        tokenReserve = newTokenReserve;
        totalVolumeTao += msg.value;
        totalTrades += 1;

        // Transfer tokens to buyer
        balanceOf[address(this)] -= tokensOut;
        balanceOf[recipient] += tokensOut;
        emit Transfer(address(this), recipient, tokensOut);

        // Distribute fees
        _distributeFees(deployerFee, protocolFee);

        emit Buy(recipient, msg.value, tokensOut, getPrice(), realTaoReserve, tokenReserve, block.timestamp);
    }

    function sell(uint256 tokenAmount, uint256 minTaoOut, uint256 deadline) external nonReentrant {
        require(tokenAmount > 0, "zero amount");
        require(balanceOf[msg.sender] >= tokenAmount, "insufficient balance");
        require(block.timestamp <= deadline, "expired");

        // Constant product AMM: x * y = k
        // Round newEffectiveTao UP → trader gets less TAO → k never decreases
        uint256 effectiveTao = virtualTaoReserve + realTaoReserve;
        uint256 k = effectiveTao * tokenReserve;
        uint256 newTokenReserve = tokenReserve + tokenAmount;
        uint256 newEffectiveTao = (k + newTokenReserve - 1) / newTokenReserve;
        uint256 grossTaoOut = effectiveTao - newEffectiveTao;

        // Cap grossTaoOut to available liquidity (handles Bittensor ED deficit + fee dust)
        uint256 available = realTaoReserve < address(this).balance ? realTaoReserve : address(this).balance;
        require(available > 0, "insufficient liquidity");
        if (grossTaoOut > available) {
            grossTaoOut = available;
            // H-01 FIX: Don't recalculate newTokenReserve — keep it as tokenReserve + tokenAmount
            // Floor division at the old line created phantom tokens (balanceOf > tokenReserve)
            // Seller gets less TAO but returns same tokens → k_new > k_old (safe)
        }

        // Fetch fee rates from factory — single-step calculation for precision
        (uint256 feeRate, uint256 deployerRate) = IBrainFactory(factory).getFees();
        uint256 totalFee;
        uint256 deployerFee;
        uint256 protocolFee;

        if (feeRate > 0) {
            totalFee = grossTaoOut * feeRate / FEE_DENOMINATOR;
            deployerFee = grossTaoOut * deployerRate / FEE_DENOMINATOR;
            protocolFee = totalFee - deployerFee;
        }

        uint256 netTaoOut = grossTaoOut - totalFee;
        require(netTaoOut >= minTaoOut, "slippage");

        // Update state — cap realTaoReserve to not underflow
        tokenReserve = newTokenReserve;
        realTaoReserve = grossTaoOut >= realTaoReserve ? 0 : realTaoReserve - grossTaoOut;
        totalVolumeTao += grossTaoOut;
        totalTrades += 1;

        // Return tokens to pool
        balanceOf[msg.sender] -= tokenAmount;
        balanceOf[address(this)] += tokenAmount;
        emit Transfer(msg.sender, address(this), tokenAmount);

        // Distribute fees
        _distributeFees(deployerFee, protocolFee);

        // Send TAO to seller
        require(address(this).balance >= netTaoOut, "insufficient contract balance");
        (bool success,) = payable(msg.sender).call{value: netTaoOut}("");
        require(success, "tao transfer failed");

        emit Sell(msg.sender, tokenAmount, netTaoOut, getPrice(), realTaoReserve, tokenReserve, block.timestamp);
    }

    /// @dev Deposits both fees into factory (pull pattern) — H-02 FIX
    function _distributeFees(uint256 deployerFee, uint256 protocolFee) internal {
        if (deployerFee == 0 && protocolFee == 0) return;

        // Creator fee accumulates in the factory, claimed later
        if (deployerFee > 0) {
            IBrainFactory(factory).depositCreatorFee{value: deployerFee}(creator);
        }

        // Protocol fee accumulates in the factory, claimed by owner
        if (protocolFee > 0) {
            IBrainFactory(factory).depositProtocolFee{value: protocolFee}();
        }
    }

    // ──── View ────

    function getPrice() public view returns (uint256) {
        return (virtualTaoReserve + realTaoReserve) * 10 ** 18 / tokenReserve;
    }

    function getAmountOut(uint256 taoIn) external view returns (uint256 tokensOut) {
        (uint256 feeRate,) = IBrainFactory(factory).getFees();
        uint256 fee = taoIn * feeRate / FEE_DENOMINATOR;
        uint256 netTaoIn = taoIn - fee;
        uint256 effectiveTao = virtualTaoReserve + realTaoReserve;
        uint256 k = effectiveTao * tokenReserve;
        tokensOut = tokenReserve - (k / (effectiveTao + netTaoIn));
    }

    function getTaoOut(uint256 tokenAmount) external view returns (uint256 taoOut) {
        (uint256 feeRate,) = IBrainFactory(factory).getFees();
        uint256 effectiveTao = virtualTaoReserve + realTaoReserve;
        uint256 k = effectiveTao * tokenReserve;
        uint256 grossTaoOut = effectiveTao - (k / (tokenReserve + tokenAmount));
        uint256 fee = grossTaoOut * feeRate / FEE_DENOMINATOR;
        taoOut = grossTaoOut - fee;
    }

    function getReserves() external view returns (uint256, uint256, uint256) {
        return (virtualTaoReserve, realTaoReserve, tokenReserve);
    }

    function getMarketCap() external view returns (uint256) {
        return getPrice() * TOTAL_SUPPLY / 10 ** 18;
    }

    function getTokenInfo()
        external
        view
        returns (
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
        return (
            name,
            symbol,
            metadata,
            creator,
            createdAt,
            getPrice(),
            virtualTaoReserve,
            realTaoReserve,
            tokenReserve,
            totalVolumeTao,
            totalTrades,
            getPrice() * TOTAL_SUPPLY / 10 ** 18
        );
    }
}
