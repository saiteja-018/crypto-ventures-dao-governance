// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ITreasury
 * @notice Interface for treasury management
 */
interface ITreasury {
    enum FundCategory {
        HighConviction,
        ExperimentalBet,
        OperationalExpense
    }

    /**
     * @notice Gets the balance of a fund category
     * @param category The fund category
     * @return The balance in wei
     */
    function getBalance(FundCategory category) external view returns (uint256);

    /**
     * @notice Gets the balance limit for a fund category
     * @param category The fund category
     * @return The balance limit in wei
     */
    function getBalanceLimit(FundCategory category) external view returns (uint256);

    /**
     * @notice Gets the total treasury balance
     * @return The total balance in wei
     */
    function getTotalBalance() external view returns (uint256);

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
    ) external;
}
