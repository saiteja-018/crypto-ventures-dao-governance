// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../interfaces/IDelegation.sol";
import "./GovernanceToken.sol";

/**
 * @title VotingDelegation
 * @notice Manages voting delegation with support for revoking delegations
 */
contract VotingDelegation is IDelegation {
    // References
    GovernanceToken private _governanceToken;

    // State variables
    mapping(address => address) private _delegations; // delegator => delegatee
    mapping(address => address[]) private _delegators; // delegatee => array of delegators

    // Events
    event DelegationCreated(address indexed delegator, address indexed delegatee);
    event DelegationRevoked(address indexed delegator);

    /**
     * @notice Initializes the delegation contract
     * @param governanceToken The governance token contract address
     */
    constructor(address governanceToken) {
        require(governanceToken != address(0), "Invalid governance token address");
        _governanceToken = GovernanceToken(payable(governanceToken));
    }

    /**
     * @notice Delegates voting power to another address
     * @param delegatee The address to delegate voting power to
     */
    function delegate(address delegatee) external {
        require(delegatee != address(0), "Invalid delegatee");
        require(delegatee != msg.sender, "Cannot delegate to self");
        require(_governanceToken.getStake(msg.sender) > 0, "No stake to delegate");

        // If already delegated to someone else, remove from their delegators list
        if (_delegations[msg.sender] != address(0)) {
            _removeDelegator(_delegations[msg.sender], msg.sender);
        }

        _delegations[msg.sender] = delegatee;
        _delegators[delegatee].push(msg.sender);

        emit DelegationCreated(msg.sender, delegatee);
    }

    /**
     * @notice Revokes delegation
     */
    function revokeDelegation() external {
        require(_delegations[msg.sender] != address(0), "No delegation to revoke");

        address delegatee = _delegations[msg.sender];
        _delegations[msg.sender] = address(0);
        _removeDelegator(delegatee, msg.sender);

        emit DelegationRevoked(msg.sender);
    }

    /**
     * @notice Gets the delegate of a member
     * @param delegator The delegator address
     * @return The delegatee address (zero address if no delegation)
     */
    function getDelegation(address delegator) external view returns (address) {
        return _delegations[delegator];
    }

    /**
     * @notice Gets the voting power including delegations
     * @param account The account address
     * @return The total voting power (own + delegated)
     */
    function getVotingPowerWithDelegation(address account) external view returns (uint256) {
        uint256 ownPower = _governanceToken.getVotingPower(account);
        uint256 delegatedPower = _getDelegatedPower(account);
        return ownPower + delegatedPower;
    }

    /**
     * @notice Gets all delegators for an account
     * @param delegatee The delegatee address
     * @return The array of delegators
     */
    function getDelegators(address delegatee) external view returns (address[] memory) {
        return _delegators[delegatee];
    }

    /**
     * @notice Gets the total delegated power to an account
     * @param account The account address
     * @return The total delegated voting power
     */
    function _getDelegatedPower(address account) internal view returns (uint256) {
        uint256 totalDelegatedPower = 0;
        address[] memory delegators = _delegators[account];

        for (uint256 i = 0; i < delegators.length; i++) {
            totalDelegatedPower += _governanceToken.getVotingPower(delegators[i]);
        }

        return totalDelegatedPower;
    }

    /**
     * @notice Removes a delegator from the delegators list
     * @param delegatee The delegatee address
     * @param delegator The delegator address to remove
     */
    function _removeDelegator(address delegatee, address delegator) internal {
        address[] storage delegators = _delegators[delegatee];
        
        for (uint256 i = 0; i < delegators.length; i++) {
            if (delegators[i] == delegator) {
                delegators[i] = delegators[delegators.length - 1];
                delegators.pop();
                break;
            }
        }
    }
}
