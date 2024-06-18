// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/IMetadataRenderer.sol";

abstract contract Tickets is
    Ownable
{
    struct Probabilities {
        uint256 Bronze;
        uint256 Silver;
        uint256 Gold;
        uint256 Diamond;
        uint256 Emerald;
    }
    uint256 private _firstSnapshot;
    uint256 private _lastSnapshot;
    mapping(uint256 => Probabilities) private _snapshotProbabilities;

    ///
    /// Allows the contract to view the ticket probabilities
    /// - ticket probabilities are used to determine the rarity of a ticket
    /// - ticket probabilities are dynamic and can be updated by the contract
    /// - you can view the ticket probabilities at a specific timestamp
    ///

    function _ticketProbability(IMetadataRenderer.TicketType ticketType, uint256 timestamp) internal view returns (uint256) {
        Probabilities memory p = _getProbabilities(timestamp);
        if (ticketType == IMetadataRenderer.TicketType.Bronze) {
            return p.Bronze;
        }
        if (ticketType == IMetadataRenderer.TicketType.Silver) {
            return p.Silver;
        }
        if (ticketType == IMetadataRenderer.TicketType.Gold) {
            return p.Gold;
        }
        if (ticketType == IMetadataRenderer.TicketType.Diamond) {
            return p.Diamond;
        }
        if (ticketType == IMetadataRenderer.TicketType.Emerald) {
            return p.Emerald;
        }

        return 0;
    }
    function ticketProbability(IMetadataRenderer.TicketType ticketType) external view returns (uint256) {
        return _ticketProbability(ticketType, _lastSnapshot);
    }

    ///
    /// Allows the contract to modify & update the ticket probabilities
    ///

    event ProbabilitySnapshot(uint256 timestamp, Probabilities probabilities);

    function _takeProbabilitySnapshot() internal {
        _setProbabilities(_updateProbabilities(_getProbabilities(_lastSnapshot)));
    }
    function _setInitialProbabilities(Probabilities memory p) internal {
        _firstSnapshot = block.timestamp;
        _setProbabilities(p);
    }
    function _setProbabilities(Probabilities memory p) internal {
        _snapshotProbabilities[block.timestamp] = p;
        _lastSnapshot = block.timestamp;
        emit ProbabilitySnapshot(block.timestamp, p);
    }
    function _getProbabilities(uint256 timestamp) internal view returns (Probabilities memory p) {
        // return 0 probabilities if timestamp is before the first snapshot
        if (timestamp < _firstSnapshot) {
            return Probabilities(0, 0, 0, 0, 0);
        }

        // use the last snapshot if no probabilities are set
        p = _snapshotProbabilities[timestamp];
        if (p.Emerald == 0) {
            p = _snapshotProbabilities[_lastSnapshot];
        }
    }
    function _updateProbabilities(Probabilities memory probabilities) internal view virtual returns (Probabilities memory);

    function _firstSnapshotTimestamp() internal view returns (uint256) {
        return _firstSnapshot;
    }
    function _lastSnapshotTimestamp() internal view returns (uint256) {
        return _lastSnapshot;
    }
    function snapshotTimestamps() external view returns (uint256 first, uint256 last) {
        return (_firstSnapshot, _lastSnapshot);
    }
    function probabilitiesFor(uint256 timestamp) external view returns (Probabilities memory) {
        return _getProbabilities(timestamp);
    }

    ///
    /// Allows the contract to decrease the reward for a ticket
    /// - reward decreases by 2.5% every period
    ///

    function _decreasePeriod() internal virtual view returns (uint256);
    function _decreaseRewardByTime(uint256 reward, uint256 timestamp) internal view returns (uint256) {
        uint256 periodPassed = (block.timestamp - timestamp) / _decreasePeriod();
        uint256 decrease = reward * periodPassed * 25 / 1000;
        return reward > decrease ? reward - decrease : 0;
    }
    function decreasePeriod() external view returns (uint256) {
        return _decreasePeriod();
    }

    ///
    /// Allows the contract to determine the rarity of a ticket
    /// - ticket rarity is determined by the ticket probabilities
    ///

    function _applyReferralBonus(Probabilities memory p) internal pure virtual returns (Probabilities memory);
    function _ticketTypeOf(uint256 seed, uint256 timestamp, bool hasRef) internal view returns (IMetadataRenderer.TicketType) {
        // if seed is 0, return "try again"
        if (seed == 0) {
            return IMetadataRenderer.TicketType.TryAgain;
        }

        // check if ticket is still valid
        uint256 maxPeriod = _decreasePeriod() * 1000 / 25;
        if (
            timestamp < _lastSnapshotTimestamp() ||
            block.timestamp - timestamp > maxPeriod
        ) {
            return IMetadataRenderer.TicketType.TryAgain;
        }

        // get the probabilities (return unknown if no probabilities are set)
        Probabilities memory p = _snapshotProbabilities[timestamp];
        if (p.Emerald == 0) {
            return IMetadataRenderer.TicketType.TryAgain;
        }

        // update the probabilities based on the user's referral status
        if (hasRef) {
            p = _applyReferralBonus(p);
        }

        // calculate the rarity of the ticket
        if (seed % p.Emerald == 0) {
            return IMetadataRenderer.TicketType.Emerald;
        }
        if (seed % p.Diamond == 0) {
            return IMetadataRenderer.TicketType.Diamond;
        }
        if (seed % p.Gold == 0) {
            return IMetadataRenderer.TicketType.Gold;
        }
        if (seed % p.Silver == 0) {
            return IMetadataRenderer.TicketType.Silver;
        }
        if (seed % p.Bronze == 0) {
            return IMetadataRenderer.TicketType.Bronze;
        }

        // if no ticket type is found, return try again
        return IMetadataRenderer.TicketType.TryAgain;
    }

    ///
    /// Allows owner to set the ticket probabilities
    /// - probabilities can't be set to 0
    /// - probabilities must be in increasing order
    ///

    error InvalidProbabilityInputs();
    event ProbabilitiesChanged(Probabilities probabilities);

    function _validateProbabilities(Probabilities calldata p) internal virtual pure {
        if (
            p.Bronze == 0 ||
            p.Silver == 0 ||
            p.Gold == 0 ||
            p.Diamond == 0 ||
            p.Emerald == 0
        ) {
            revert InvalidProbabilityInputs();
        }

        if (
            p.Bronze >= p.Silver ||
            p.Silver >= p.Gold ||
            p.Gold >= p.Diamond ||
            p.Diamond >= p.Emerald
        ) {
            revert InvalidProbabilityInputs();
        }
    }
    function setProbabilities(Probabilities calldata p) external onlyOwner {
        _validateProbabilities(p);
        _setProbabilities(p);
        emit ProbabilitiesChanged(p);
    }

    ///
    /// Allows contract to keep track of the total minted rarity
    /// - total minted rarity is the sum of all ticket rarities
    /// - gets increased/decreased when tickets are minted/burned
    /// - used to calculate the prize reward for a ticket
    ///

    uint256 private _totalTicketProbabilities = 0;

    event UpdatedTotalMinted(uint256 indexed totalMinted);

    function _normalizeSeed(uint256 rawSeed, uint256 tokenId) internal virtual view returns(uint256);
    function _incrementTotalTicketProbabilities(uint256 amount) internal {
        _totalTicketProbabilities += amount;
        emit UpdatedTotalMinted(_totalTicketProbabilities);
    }
    function _computeProbability(uint256 rawSeed, uint256 tokenId, uint256 timestamp, bool hasRef) internal view returns (uint256) {
        uint256 seed = _normalizeSeed(rawSeed, tokenId);
        return _ticketProbability(_ticketTypeOf(seed, timestamp, hasRef), _firstSnapshot);
    }
    function _registerTicketsWithRange(
        uint256 rawSeed,
        uint256 fromId,
        uint256 toId,
        uint256 revealTimestamp,
        bool hasRef
    ) internal {
        (uint256 total, uint256 i) = (0, 0);
        for (i = fromId; i < toId; i++) {
            total += _computeProbability(rawSeed, i, revealTimestamp, hasRef);
        }
        _incrementTotalTicketProbabilities(total);
    }
    function _registerTicketsWithIds(
        uint256 rawSeed,
        uint256[] memory tokenIds,
        uint256 revealTimestamp,
        bool hasRef
    ) internal {
        (uint256 total, uint256 i) = (0, 0);
        for (i = 0; i < tokenIds.length; i++) {
            total += _computeProbability(rawSeed, tokenIds[i], revealTimestamp, hasRef);
        }
        _incrementTotalTicketProbabilities(total);
    }
    function _deregisterTicket(uint256 seed, uint256 timestamp, bool hasRef) internal {
        _totalTicketProbabilities -= _ticketProbability(_ticketTypeOf(seed, timestamp, hasRef), _firstSnapshot);
        emit UpdatedTotalMinted(_totalTicketProbabilities);
    }
    function _getTotalTicketProbabilities() internal view returns (uint256) {
        return _totalTicketProbabilities;
    }
    function totalTicketProbabilities() external view returns (uint256) {
        return _getTotalTicketProbabilities();
    }

    ///
    /// Allows contract to calculate the prize reward for a ticket
    ///

    function _getRewardForTicketType(
        IMetadataRenderer.TicketType ticketType,
        uint256 totalPrizePool_,
        uint256 totalTicketProbabilities_
    ) internal view virtual returns (uint256) {
        // if no tickets are minted, return 0
        if (totalTicketProbabilities_ == 0) {
            return 0;
        }

        // limit the prize pool based on the total minted rarity
        uint256 divider = 90;
        uint256 timestamp = _firstSnapshot;
        if (totalTicketProbabilities_ < _ticketProbability(IMetadataRenderer.TicketType.Gold, timestamp)) {
            divider = 10;  // max. 10% of the prize pool
        } else if (totalTicketProbabilities_ < _ticketProbability(IMetadataRenderer.TicketType.Diamond, timestamp)) {
            divider = 25;  // max. 25% of the prize pool
        } else if (totalTicketProbabilities_ < _ticketProbability(IMetadataRenderer.TicketType.Emerald, timestamp)) {
            divider = 50;  // max. 50% of the prize pool
        } else if (totalTicketProbabilities_ < 3*_ticketProbability(IMetadataRenderer.TicketType.Emerald, timestamp)) {
            divider = 66;  // max. 66% of the prize pool
        }

        // calculate the prize & normalize it
        uint256 totalPool = totalPrizePool_ * divider / 100;
        uint256 prize = (totalPool * _ticketProbability(ticketType, _firstSnapshot)) / totalTicketProbabilities_;
        if (prize > totalPrizePool_) {
            return totalPrizePool_;
        }

        return prize;
    }
    function getRewardForTicketType(IMetadataRenderer.TicketType ticketType) public view returns (uint256) {
        return _getRewardForTicketType(ticketType, _totalPrizePool(), _getTotalTicketProbabilities());
    }
    function _totalPrizePool() internal view virtual returns (uint256);

    ///
    /// Allows contract to limit the number of tickets that can be fulfilled with seed
    /// - ticket refresh must be min. 25 TICKET
    ///

    uint256 private _maxTicketRefresh = type(uint256).max;

    error InvalidMaxTicketRefresh();
    event MaxTicketRefreshChanged(uint256 amount);

    function _setMaxTicketRefresh(uint256 amount) internal {
        if (amount < 100) {  // 100 TICKET min.
            revert InvalidMaxTicketRefresh();
        }
        _maxTicketRefresh = amount;
    }
    function _getMaxTicketRefresh() internal view returns (uint256) {
        return _maxTicketRefresh;
    }
    function setMaxTicketRefresh(uint256 amount) external onlyOwner {
        _setMaxTicketRefresh(amount);
        emit MaxTicketRefreshChanged(amount);
    }
    function maxTicketRefresh() external view returns (uint256) {
        return _getMaxTicketRefresh();
    }
}