// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/ITreasury.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DAOTreasury
 * @notice Manages multi-tier treasury with category-specific balance limits
 */
contract DAOTreasury is ITreasury, Ownable {
    // Treasury balances by category
    mapping(FundCategory => uint256) private _balances;
    mapping(FundCategory => uint256) private _balanceLimits;

    // Events
    event FundsReceived(address indexed from, uint256 amount);
    event FundsTransferred(FundCategory indexed category, address indexed recipient, uint256 amount);
    event BalanceLimitUpdated(FundCategory indexed category, uint256 newLimit);

    /**
     * @notice Initializes the treasury with balance limits
     * @param highConvictionLimit The limit for high conviction investments
     * @param experimentalLimit The limit for experimental bets
     * @param operationalLimit The limit for operational expenses
     */
    constructor(
        address initialOwner,
        uint256 highConvictionLimit,
        uint256 experimentalLimit,
        uint256 operationalLimit
    ) Ownable(initialOwner) {
        _balanceLimits[FundCategory.HighConviction] = highConvictionLimit;
        _balanceLimits[FundCategory.ExperimentalBet] = experimentalLimit;
        _balanceLimits[FundCategory.OperationalExpense] = operationalLimit;
    }

    /**
     * @notice Gets the balance of a fund category
     * @param category The fund category
     * @return The balance in wei
     */
    function getBalance(FundCategory category) external view returns (uint256) {
        return _balances[category];
    }

    /**
     * @notice Gets the balance limit for a fund category
     * @param category The fund category
     * @return The balance limit in wei
     */
    function getBalanceLimit(FundCategory category) external view returns (uint256) {
        return _balanceLimits[category];
    }

    /**
     * @notice Gets the total treasury balance
     * @return The total balance in wei
     */
    function getTotalBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Deposits funds into a specific category
     * @param category The fund category
     */
    function depositToCategory(FundCategory category) external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        require(
            _balances[category] + msg.value <= _balanceLimits[category],
            "Deposit exceeds category limit"
        );

        _balances[category] += msg.value;
        emit FundsReceived(msg.sender, msg.value);
    }

    /**
     * @notice Transfers funds from treasury
     * @param category The fund category
     * @param recipient The recipient address
     * @param amount The amount to transfer
     */
    function transferFunds(
        FundCategory category,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than 0");
        require(_balances[category] >= amount, "Insufficient balance in category");
        require(address(this).balance >= amount, "Insufficient treasury balance");

        _balances[category] -= amount;

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsTransferred(category, recipient, amount);
    }

    /**
     * @notice Updates the balance limit for a fund category
     * @param category The fund category
     * @param newLimit The new balance limit
     */
    function setBalanceLimit(FundCategory category, uint256 newLimit) external onlyOwner {
        _balanceLimits[category] = newLimit;
        emit BalanceLimitUpdated(category, newLimit);
    }

    /**
     * @notice Allows the contract to receive ETH
     */
    receive() external payable {
        emit FundsReceived(msg.sender, msg.value);
    }
}
