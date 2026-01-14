// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IGovernanceToken.sol";

/**
 * @title GovernanceToken
 * @notice Manages governance stakes and voting power with quadratic voting to prevent whale dominance
 */
contract GovernanceToken is IGovernanceToken {
    // State variables
    mapping(address => uint256) private _stakes;
    uint256 private _totalStake;

    // Constants for voting power calculation
    uint256 private constant PRECISION = 1e18;

    // Events
    event Deposited(address indexed member, uint256 amount, uint256 newStake, uint256 votingPower);
    event Withdrawn(address indexed member, uint256 amount, uint256 newStake);

    /**
     * @notice Deposits ETH into the DAO treasury
     * @dev Uses quadratic voting: voting power = sqrt(stake)
     */
    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        _stakes[msg.sender] += msg.value;
        _totalStake += msg.value;

        uint256 votingPower = getVotingPower(msg.sender);
        
        emit Deposited(msg.sender, msg.value, _stakes[msg.sender], votingPower);
    }

    /**
     * @notice Withdraws staked ETH from the DAO
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Withdraw amount must be greater than 0");
        require(_stakes[msg.sender] >= amount, "Insufficient stake");

        _stakes[msg.sender] -= amount;
        _totalStake -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed");

        emit Withdrawn(msg.sender, amount, _stakes[msg.sender]);
    }

    /**
     * @notice Calculates voting power using quadratic formula
     * @dev Voting power = sqrt(stake) to reduce whale dominance
     * @param member The member's address
     * @return The voting power
     */
    function getVotingPower(address member) public view returns (uint256) {
        uint256 stake = _stakes[member];
        if (stake == 0) return 0;

        // Use sqrt for quadratic voting to reduce whale dominance
        // voting_power = sqrt(stake) * precision_scale
        return _sqrt(stake * PRECISION);
    }

    /**
     * @notice Gets the total voting power in the DAO
     * @return The sum of all members' voting power
     */
    function getTotalVotingPower() public view returns (uint256) {
        if (_totalStake == 0) return 0;
        return _sqrt(_totalStake * PRECISION);
    }

    /**
     * @notice Gets the stake of a member
     * @param member The member's address
     * @return The member's stake in wei
     */
    function getStake(address member) external view returns (uint256) {
        return _stakes[member];
    }

    /**
     * @notice Gets the total stake in the DAO
     * @return The total stake in wei
     */
    function getTotalStake() external view returns (uint256) {
        return _totalStake;
    }

    /**
     * @notice Internal function to calculate square root
     * @param x The number to calculate sqrt of
     * @return The square root of x
     */
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        
        // Newton's method for calculating square root
        uint256 result = x;
        uint256 k = (x >> 1) + 1;
        
        while (k < result) {
            result = k;
            k = (x / k + k) >> 1;
        }
        
        return result;
    }

    /**
     * @notice Allows the contract to receive ETH
     */
    receive() external payable {}
}
