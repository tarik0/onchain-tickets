// SPDX-License-Identifier: MIT
//
//   ░▒▓██████▓▒░░▒▓███████▓▒░ ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░░▒▓█▓▒░▒▓███████▓▒░
//  ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
//  ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
//  ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓████████▓▒░▒▓████████▓▒░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
//  ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
//  ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
//   ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
//
//
//  ░▒▓████████▓▒░▒▓█▓▒░░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓████████▓▒░▒▓████████▓▒░▒▓███████▓▒░
//     ░▒▓█▓▒░   ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░         ░▒▓█▓▒░  ░▒▓█▓▒░
//     ░▒▓█▓▒░   ░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░         ░▒▓█▓▒░  ░▒▓█▓▒░
//     ░▒▓█▓▒░   ░▒▓█▓▒░▒▓█▓▒░      ░▒▓███████▓▒░░▒▓██████▓▒░    ░▒▓█▓▒░   ░▒▓██████▓▒░
//     ░▒▓█▓▒░   ░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░         ░▒▓█▓▒░         ░▒▓█▓▒░
//     ░▒▓█▓▒░   ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░         ░▒▓█▓▒░         ░▒▓█▓▒░
//     ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓████████▓▒░  ░▒▓█▓▒░  ░▒▓███████▓▒░
//
// * Website : https://onchaintickets.xyz/
// * Twitter : https://twitter.com/onchaintickets
// * Warpcast: https://warpcast.com/onchaintickets
// * Telegram: https://t.me/onchaintickets
// * Discord : https://discord.gg/aKr5x2fa6u
// * Github  : https://github.com/onchaintickets
//
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./dn404/DN404.sol";

import "./helpers/token/Base.sol";
import "./helpers/token/Tickets.sol";
import "./helpers/token/Trade.sol";
import "./helpers/token/QRND.sol";
import "./helpers/token/Fallback.sol";

import "./interfaces/IWETH9.sol";
import "./interfaces/ISwapRouter02.sol";
import "./interfaces/IMetadataRenderer.sol";
import "./interfaces/IReferrals.sol";

contract Tickets404 is
    Base,
    QRND,
    Trade,
    Tickets,
    Fallback
{
    ///
    /// Constructor
    ///

    constructor() {
        // initial ticket probabilities
        // Probability ~= 1 / weight
        _setInitialProbabilities(Probabilities({
            Bronze: 2_000,  // 1 / 2_000 = 0.05%
            Silver: 12_000,  // 1 / 12_000 = 0.008333%
            Gold: 36_000,  // 1 / 36_000 = 0.002777%
            Diamond: 72_000,  // 1 / 72_000 = 0.001388%
            Emerald: 144_000  // 1 / 144_000 = 0.000694%
        }));
    }

    ///
    /// Allows the owner to initialize the contract
    /// - first step is to initialize the DN404 token
    /// - second step is to initialize the swap pool
    /// - third step is to enable the contract (starts trading)
    ///

    error AlreadyInitialized();

    function initializeToken(
        QRND.AirnodeSettings calldata airnodeSettings,
        address mirror,
        address renderer,
        address referrals
    ) external onlyOwner {
        // check if the contract is already initialized
        if (_getReferrals() != address(0)) {
            revert AlreadyInitialized();
        }

        // mint DN404 tokens to the owner
        address owner = _msgSender();
        _initializeDN404(50_000 * 1e18, owner, mirror);

        // set renderer & mirror
        _setRenderer(renderer);
        _setReferrals(referrals);

        // exclude the owner from tax
        _setExcludedFromTax(referrals, true);

        // set airnode settings
        _setRequestSettings(airnodeSettings);
    }
    function initializePool(address payable router_, address posManager_, uint24 fee_) external onlyOwner {
        // check if the contract is already initialized
        address _router = _router();
        if (_router != address(0)) {
            revert AlreadyInitialized();
        }

        // initialize the pool
        _approve(address(this), router_, type(uint256).max);
        _initializePool(router_, fee_);

        // exclude pos manager from tax
        _setExcludedFromTax(posManager_, true);
    }
    function initializeTransfer() external onlyOwner {
        if (_getInitialPrice() != 0) {
            revert AlreadyInitialized();
        }

        // set default max wallet
        _setMaxWallet(1_000 * 1e18);

        // maximum ticket refresh
        _setMaxTicketRefresh(500);

        // set initial price
        _resetInitialSqrtPrice();
    }

    ///
    /// Allows the owner to use emergency functions
    ///

    function setRequestSettings(AirnodeSettings calldata airnodeSettings) external onlyOwner {
        _setRequestSettings(airnodeSettings);
        emit AirnodeSettingsChanged(airnodeSettings);
    }
    function rescueToken() external onlyOwner {
        // rescue the DN404 tokens
        uint256 amount = DN404.balanceOf(address(this));
        if (amount > 0) {
            DN404.transfer(owner(), amount);
        }

        // request withdrawal from the airnode
        AirnodeSettings memory settings = _getRequestSettings();
        IAirnodeRrpV0(settings.AirnodeRrp).requestWithdrawal(settings.Airnode, settings.SponsorWallet);
    }

    ///
    /// Allows owner to reset the initial price at emergency
    ///

    function resetInitialPrice() external onlyOwner {
        _resetInitialSqrtPrice();
    }

    ///
    /// Allows users to sync the lottery
    /// - swap tokens to WETH and create a new prize pool
    /// - update the probabilities based on the price change
    ///

    modifier syncLotteryAfter() {
        _;
        _swapTokens();
        _takeProbabilitySnapshot();
    }

    function syncLottery() external nonReentrant syncLotteryAfter {
    }

    ///
    /// Allows users to claim their ticket rewards
    /// - rewards are claimed in WETH
    /// - ticket seeds gets reset after the claim
    ///

    error RewardTransferFailed();
    error NotOwner();

    event ClaimedReward(address indexed owner, uint256 indexed tokenId, uint256 reward);

    function _claimReward(address recipient, uint256 tokenId) private {
        // get the rewards of the ticket
        uint256 reward = _getRewardOf(tokenId, _totalPrizePool(), _getTotalTicketProbabilities());
        if (reward != 0) {
            // transfer the reward to the owner
            if (!IWETH9(_WETH9()).transfer(recipient, reward)) {
                revert RewardTransferFailed();
            }
            emit ClaimedReward(recipient, tokenId, reward);
        }

        // decrease the total rarity & reset the ticket seeds & emit the event
        (uint256 seed, uint256 timestamp, bool hasRef) = _seedForTokenId(tokenId);
        _deregisterTicket(seed, timestamp, hasRef);
        _resetRequestForTokenId(tokenId);
    }
    function claimReward(uint256 tokenId) external nonReentrant {
        // check if the ticket is owned by the sender
        address account = _msgSender();
        if (_ownerOf(tokenId) != account) {
            revert NotOwner();
        }

        // claim the reward for single ticket
        _claimReward(account, tokenId);
    }
    function claimRewards(uint256 startIndex) external nonReentrant syncLotteryAfter {
        address account = _msgSender();
        uint256[] memory tokenIds = _ownedIds(account, startIndex, _balanceOfNFT(account));
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _claimReward(account, tokenIds[i]);
        }
    }

    ///
    /// Allows users to refresh their tickets
    /// - refreshment fee is %10 of the ticket price
    /// - %27 of the fee is transferred to the treasury wallet
    /// - %3 of the fee is transferred to the referrer
    /// - %70 of the fee is added to the prize pool
    /// - if the ticket fulfillment fails & it's not gonna get revealed, there are no refresh fees for the ticket
    ///

    error InsufficientFee();
    error InvalidIds();
    error InvalidTicketType(uint256 token, IMetadataRenderer.TicketType ticketType);

    uint256 private constant MAX_IDS_PER_CHUNK = 150;

    function _computeRefreshFee(uint256 fee) private pure returns (
        uint256 referralTax,
        uint256 prizePoolTax,
        uint256 treasuryTax
    ) {
        return (
            fee * 75 / 1000,  // %10 x %7.5 = %0.75 of total
            fee * 675 / 1000,  // %10 x %67.5 = %6.75 of total
            fee * 250 / 1000  // %10 x %25 = %2.5 of total
        );
    }
    function _takeRefreshFee(address sender, uint256 fee) private {
        // check if the msg.value is enough
        if (msg.value < fee) {
            revert InsufficientFee();
        }

        // compute the fee
        (uint256 refFee, uint256 ownerFee, uint256 prizeFee) = _computeRefreshFee(fee);

        // transfer the referral fee & update contract
        IReferrals ref = IReferrals(_getReferrals());
        payable(ref.referrerOf(sender)).transfer(refFee);
        ref.updateEthPrize(sender, refFee);

        // transfer the treasury fee
        payable(ref.defaultReferrer()).transfer(ownerFee);

        // wrap the rest of the fee to WETH and add it to the prize pool
        IWETH9(_WETH9()).deposit{value: prizeFee}();

        // refund the dust to the sender
        if (msg.value > fee) {
            payable(sender).transfer(msg.value - refFee - ownerFee - prizeFee);
        }
    }
    function _refreshTickets(uint256[] memory ids) internal returns (uint256) {
        address account = _msgSender();
        uint256 feeRequired = 0;

        // iterate over the tickets
        for (uint i = 0; i < ids.length; i++) {
            // check if the ticket is owned by the sender
            if (_ownerOf(ids[i]) != account) {
                revert NotOwner();
            }

            IMetadataRenderer.Ticket memory ticket = _getTicket(ids[i]);
            bytes32 reqId = _requestIdForTokenId(ids[i]);

            // don't add fee if the ticket is "unknown" and the fulfillment failed
            if (
                ticket.ticketType == IMetadataRenderer.TicketType.Unknown &&
                _isRequestFailed(reqId, _isRequestPending(reqId))
            ) {
                continue;
            }

            // add fee if the ticket is "try again"
            if (ticket.ticketType == IMetadataRenderer.TicketType.TryAgain) {
                feeRequired += 1;
                continue;
            }

            revert InvalidTicketType(ids[i], ticket.ticketType);
        }

        // reset & request seeds for the tickets
        _requestSeedForIds(ids, _lastSnapshotTimestamp());
        return feeRequired;
    }
    function refreshTickets(uint256[] memory ids) external payable nonReentrant syncLotteryAfter {
        // require the ids to be non-empty
        if (ids.length == 0) {
            revert InvalidIds();
        }

        // check max ticket refresh
        // fulfill with ids consumes more gas so we need to limit the ids
        if (ids.length > _getMaxTicketRefresh()) {
            revert TransferWithLess();
        }

        // split the ids into 175 size chunks & feed them to the refresh function
        uint256 totalFeeRequired = 0;
        for (uint256 i = 0; i < ids.length; i += MAX_IDS_PER_CHUNK) {
            uint256 end = i + MAX_IDS_PER_CHUNK > ids.length ? ids.length : i + MAX_IDS_PER_CHUNK;
            uint256[] memory chunk = new uint256[](end - i);

            for (uint256 j = i; j < end; j++) {
                chunk[j - i] = ids[j];
            }

            totalFeeRequired += _refreshTickets(chunk);
        }

        // take the refresh fee
        _takeRefreshFee(_msgSender(), totalFeeRequired * _ticketRefreshFee());
    }

    function _ticketRefreshFee() private view returns (uint256) {
        return _getTicketPrice() / 10;
    }
    function ticketRefreshFee() public view returns (uint256) {
        return _ticketRefreshFee();
    }

    ///
    /// Allows users to query their tickets.
    /// - you can query a single ticket or multiple tickets
    ///

    function _getTicket(uint256 tokenId) private view returns (IMetadataRenderer.Ticket memory) {
        // if the token does not exist, return an empty ticket
        if (!_exists(tokenId)) {
            return IMetadataRenderer.Ticket({
                tokenId: tokenId,
                timestamp: block.timestamp,
                owner: address(0),
                ticketType: IMetadataRenderer.TicketType.TryAgain
            });
        }

        // if the seed request has not been fulfilled yet, return an unknown ticket
        bytes32 reqId = _requestIdForTokenId(tokenId);
        bool isReqPending = _isRequestPending(reqId);
        if (
            reqId != bytes32(0) &&
            (
                isReqPending ||  // if the request is pending
                _isRequestFailed(reqId, isReqPending)  // if the request is failed
            )
        ) {
            return IMetadataRenderer.Ticket({
                tokenId: tokenId,
                timestamp: block.timestamp,
                owner: _ownerAt(tokenId),
                ticketType: IMetadataRenderer.TicketType.Unknown
            });
        }

        // get the ticket information & return the ticket
        (uint256 seed, uint256 timestamp, bool hasRef) = _seedForTokenId(tokenId);
        return IMetadataRenderer.Ticket({
            tokenId: tokenId,
            timestamp: timestamp,
            owner: _ownerAt(tokenId),
            ticketType: _ticketTypeOf(seed, timestamp, hasRef)
        });
    }
    function getTicket(uint256 tokenId) external view returns (IMetadataRenderer.Ticket memory) {
        return _getTicket(tokenId);
    }
    function getTicketsOf(address owner, uint256 startIndex) external view returns (IMetadataRenderer.Ticket[] memory tickets) {
        uint256[] memory ids = _ownedIds(owner, startIndex, _balanceOfNFT(owner));
        tickets = new IMetadataRenderer.Ticket[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            tickets[i] = _getTicket(ids[i]);
        }
    }

    ///
    /// Allows users to query their rewards
    /// - you can query the reward of a single ticket or multiple tickets
    /// - ticket prizes are decreased by 2.5% per day without a claim
    ///

    function _decreasePeriod() internal virtual override view returns (uint256) {
        return 1 days;
    }
    function _getRewardsOf(uint256[] memory tokenIds) private view returns (uint256 totalReward) {
        (
            uint256 prizePool, uint256 totalProbability, uint256 timestamp
        ) = (_totalPrizePool(), _getTotalTicketProbabilities(), _firstSnapshotTimestamp());

        uint256 i; uint256 decreasedProbability;
        (i, decreasedProbability, totalReward) = (0, 0, 0);

        for (; i < tokenIds.length; i++) {
            totalReward += _getRewardOf(
                tokenIds[i],
                prizePool - totalReward,
                totalProbability - decreasedProbability
            );
            decreasedProbability += _ticketProbability(_getTicket(tokenIds[i]).ticketType, timestamp);
        }
    }
    function _getRewardOf(uint256 tokenId, uint256 totalPrizePool_, uint256 totalProbability) private view returns (uint256) {
        (uint256 seed, uint256 timestamp, bool hasRef) = _seedForTokenId(tokenId);
        if (timestamp == 0) {
            return 0;
        }

        return _decreaseRewardByTime(
            _getRewardForTicketType(_ticketTypeOf(seed, timestamp, hasRef), totalPrizePool_, totalProbability),
            timestamp
        );
    }
    function _totalPrizePool() internal view override returns (uint256) {
        return IERC20(_WETH9()).balanceOf(address(this));
    }
    function getRewardOf(uint256 tokenId) external view returns (uint256) {
        if (!_exists(tokenId)) {
            return 0;
        }
        return _getRewardOf(tokenId, _totalPrizePool(), _getTotalTicketProbabilities());
    }
    function getRewardsOf(address owner, uint256 startIndex) external view returns (uint256) {
        uint256[] memory tokenIds = _ownedIds(owner, startIndex, _balanceOfNFT(owner));
        return _getRewardsOf(tokenIds);
    }
    function totalPrizePool() external view returns (uint256) {
        return _totalPrizePool();
    }

    ///
    /// Allows users to query the default probabilities & ticket rewards
    ///

    function getRewardsWithProbabilities() external view returns (
        uint256[] memory ticketRewards,
        uint256[] memory ticketProbabilities
    ) {
        uint256 ticketTypeCount = uint(IMetadataRenderer.TicketType.Emerald) + 1;
        ticketRewards = new uint256[](ticketTypeCount);
        ticketProbabilities = new uint256[](ticketTypeCount);

        for (uint256 i = uint(IMetadataRenderer.TicketType.TryAgain); i < ticketTypeCount; i++) {
            IMetadataRenderer.TicketType ticketType = IMetadataRenderer.TicketType(i);
            ticketRewards[i] = getRewardForTicketType(ticketType);
            ticketProbabilities[i] = _ticketProbability(ticketType, _firstSnapshotTimestamp());
        }
    }

    ///
    /// Allows contract to keep track of the total rarity
    /// - total rarity is used to compute the ticket rewards
    ///
    /// 2**8 < rawSeed < 2**256
    /// normalizedSeed = rawSeed ^ tokenId % 2**32
    /// normalizedSeed % probability == 0
    ///

    function _normalizeSeed(uint256 seed, uint256 tokenId) internal pure override(QRND, Tickets) returns (uint256) {
        // limit to 32 bits
        return seed > 0 ? (seed ^ tokenId) % type(uint32).max : 0;
    }
    function _afterFulfillWithRange(uint256 rawSeed, uint256 fromId, uint256 toId, bool hasReferral) internal override {
        // register the tickets & increase the total rarity
        _registerTicketsWithRange(rawSeed, fromId, toId, _lastSnapshotTimestamp(), hasReferral);
    }
    function _afterFulfillWithIds(uint256 seed, uint256[] memory ids, bool hasRef) internal override {
        // register the tickets & increase the total rarity
        _registerTicketsWithIds(seed, ids, _lastSnapshotTimestamp(), hasRef);
    }
    function _useAfterNFTTransfers() internal pure override returns (bool) {
        return true;
    }
    function _afterNFTTransfers(address[] memory, address[] memory recipients, uint256[] memory ids) internal override {
        for (uint256 i = 0; i < recipients.length; i++) {
            // if the ticket is burned, deregister it
            if (recipients[i] == address(0)) {
                (uint256 seed, uint256 timestamp, bool hasRef) = _seedForTokenId(ids[i]);
                if (seed != 0 && timestamp != 0) {
                    _deregisterTicket(seed, timestamp, hasRef);
                    _resetRequestForTokenId(ids[i]);
                }
            }
        }
    }

    ///
    /// Allows contract to update the probabilities
    /// - probabilities are updated based on the price change
    /// - if the price increases, the probabilities also increase
    /// - probabilities are increased/decreased by 1% per price multiplier
    /// - probabilities are updated if the price is min. 2x higher or lower (no update between 1x and 2x)
    /// - probabilities are limited to max. 2**32-1 and min. 2**8-1
    /// - probabilities are decreased by 10% for each ticket type when a referral bonus is applied
    ///

    function _limitIncrease(uint256 probability, uint256 multiplier, uint256 divider) private pure returns (uint256) {
        uint256 increase = probability * multiplier / divider;

        // check if overflows uint256
        if (increase > (type(uint256).max - probability)) {
            return type(uint32).max;
        }
        // check if overflows uint32
        if (probability + increase > type(uint32).max) {
            return type(uint32).max;
        }

        return probability + increase;
    }
    function _limitDecrease(uint256 probability, uint256 multiplier, uint256 divider) private pure returns (uint256) {
        uint256 decrease = probability * multiplier / divider;

        // check if underflow
        if (decrease >= probability) {
            return type(uint8).max;
        }
        // check if lower than uint8
        if ((probability - decrease) < uint256(type(uint8).max)) {
            return type(uint8).max;
        }

        return probability - decrease;
    }
    function _increaseProbabilities(
        Probabilities memory p,
        uint256 multiplier,
        uint256 divider
    ) private pure returns (Probabilities memory) {
        return Probabilities({
            Bronze: _limitIncrease(p.Bronze, multiplier, divider),
            Silver: _limitIncrease(p.Silver, multiplier, divider),
            Gold: _limitIncrease(p.Gold, multiplier, divider),
            Diamond: _limitIncrease(p.Diamond, multiplier, divider),
            Emerald: _limitIncrease(p.Emerald, multiplier, divider)
        });
    }
    function _decreaseProbabilities(
        Probabilities memory p,
        uint256 multiplier,
        uint256 divider
    ) private pure returns (Probabilities memory) {
        return Probabilities({
            Bronze: _limitDecrease(p.Bronze, multiplier, divider),
            Silver: _limitDecrease(p.Silver, multiplier, divider),
            Gold: _limitDecrease(p.Gold, multiplier, divider),
            Diamond: _limitDecrease(p.Diamond, multiplier, divider),
            Emerald: _limitDecrease(p.Emerald, multiplier, divider)
        });
    }
    function _updateProbabilities(Probabilities memory p) internal view override returns (Probabilities memory) {
        // skip if the contract is not initialized
        if (!_isInitialized()) {
            return p;
        }

        // get 1 token price in WETH to compare with the initial price
        (
            uint256 currentPrice,
            uint256 initialPrice
        ) = (
            _getTicketPrice(),
            _getInitialPrice()
        );
        if (currentPrice == 0 || initialPrice == 0) {
            return p;
        }

        // update probabilities depending on price change (min. 2x)
        if (currentPrice > initialPrice * 2) {
            return _decreaseProbabilities(p, currentPrice / initialPrice, 100);
        } else if (currentPrice < initialPrice / 2) {
            return _increaseProbabilities(p, initialPrice / currentPrice, 100);
        }

        return p;
    }
    function _applyReferralBonus(Probabilities memory p) internal pure override returns (Probabilities memory) {
        // decrease the probability weight 10% for each ticket type
        return _decreaseProbabilities(p, 10, 100);
    }

    ///
    /// Allows contract to check if an account has a referral
    ///

    function _hasReferral(address account) internal view override returns (bool) {
        IReferrals ref = IReferrals(_getReferrals());
        return ref.referrerOf(account) != ref.defaultReferrer();
    }

    ///
    /// Allows contract to render the metadata via the renderer
    ///

    function _tokenURI(uint256 tokenId) internal view override returns (string memory) {
        address _renderer = _getRenderer();
        return _renderer == address(0) ? "" : IMetadataRenderer(_renderer).renderURI(_getTicket(tokenId));
    }

    ///
    /// Allows contract to change NFT flags on ownership transfer
    ///

    function _transferOwnership(address newOwner) internal virtual override {
        address _owner = owner();
        if (_owner != address(0)) {
            _setSkipNFT(_owner, false);
        }
        _setSkipNFT(newOwner, true);
        Ownable._transferOwnership(newOwner);
    }

    ///
    /// Allows contract to handle transfers.
    /// - all the transfers are subject to the max wallet limit (except for the excluded addresses)
    /// - all the transfers are subject to the ticket refresh limit (this is for better fulfillment)
    /// - takes care of the prize pool tax & referral tax
    /// - requests seeds for the new tickets (if any)
    /// - updates the probabilities after the transfer
    ///

    error NotInitialized();
    error TransferWithLess();

    function _isInitialized() private view returns (bool) {
        return _pool() != address(0) && _getAirnodeRrp() != address(0) && _getInitialPrice() != 0;
    }
    function _transferWithoutNFT(
        address from_,
        address to_,
        uint amount_
    ) private {
        bool skipNFTBefore = getSkipNFT(to_);
        if (!skipNFTBefore) {
            _setSkipNFT(to_, true);
        }
        DN404._transfer(from_, to_, amount_);
        if (!skipNFTBefore) {
            _setSkipNFT(to_, false);
        }
    }
    function _computeTax(uint256 amount) private view returns (
        uint256 prizePoolTax,
        uint256 refTax
    ) {
        Tax memory tax = _getPrizePoolTax();
        return (
            amount * tax.Numerator / tax.Denominator,  // 2.7% of total
            amount * 3 / 1_000  // 0.3% of total
        );
    }
    function _buyTransfer(
        address from_,
        address to_,
        uint amount_
    ) private {
        // check if from_ is excluded from tax
        uint256 totalTax = 0;
        if (
            !_getExcludedFromTax(from_) &&
            !_getExcludedFromTax(to_)
        ) {
            // calculate the tax
            (uint256 prizePoolTax, uint256 refTax) = _computeTax(amount_);

            // transfer prize pool tax to the prize pool
            // ps. prize pool tax is not transferred with NFT
            DN404._transfer(from_, address(this), prizePoolTax);

            // find the referrer
            IReferrals ref = IReferrals(_getReferrals());
            address referrer = ref.referrerOf(from_);

            // transfer referral tax to the referrer without NFT
            _transferWithoutNFT(from_, referrer, refTax);

            // update the states
            ref.updatePrize(from_, refTax);
            totalTax = prizePoolTax + refTax;
        }

        // transfer the rest of the amount
        // ps. the total tax is deducted from the amount
        // ps. the amount is transferred with NFT
        DN404._transfer(from_, to_, amount_ - totalTax);
    }
    function _transfer(
        address from_,
        address to_,
        uint amount_
    ) internal virtual override (DN404) checkMaxWallet(to_, amount_) {
        // simple ERC20 transfer for the owner
        if (from_ == owner() || to_ == owner()) {
            _transferWithoutNFT(from_, to_, amount_);
            return;
        }

        // check if token has initialized
        address pool = _pool();
        if (!_isInitialized()) {
            revert NotInitialized();
        }

        uint256 fromId = _getDN404Storage().nextTokenId;

        // do the transfer & flag if a snapshot is needed
        bool takeSnapshot = false;
        if (from_ == pool) {
            _buyTransfer(from_, to_, amount_);
            takeSnapshot = true;
        } else if (to_ == pool) {
            DN404._transfer(from_, to_, amount_);
            takeSnapshot = true;
        } else {
            DN404._transfer(from_, to_, amount_);
        }

        // check if the transfer mints new tickets
        uint256 toId = _getDN404Storage().nextTokenId;
        if (fromId != toId) {
            // check if the transfer is within the max ticket refresh limit
            if (toId-fromId > _getMaxTicketRefresh()) {
                revert TransferWithLess();
            }

            // request seeds for the new tickets
            _requestSeedForRange(fromId, toId, _lastSnapshotTimestamp());
        }

        // take the snapshot if needed
        if (takeSnapshot) {
            _takeProbabilitySnapshot();
        }
    }

    ///
    /// Allows users to transfer their NFTs
    ///

    function transferNFT(address to, uint256 id) external {
        _transferFromNFT(_msgSender(), to, id, _msgSender());
    }

    ///
    /// Fallback
    /// - users can query this contract with an IERC721 interface
    /// - all received ether is converted to WETH and added to the prize pool
    ///

    fallback() external payable override {
        _fallback();
    }
    receive() external payable override {
        uint256 amount = msg.value;
        if (amount > 0) {
            // transfer the value to the owner if the sender is the airnode
            if (_msgSender() == _getAirnodeRrp()) {
                payable(owner()).transfer(amount);
                return;
            }

            // wrap the value to WETH and add it to the prize pool
            IWETH9(_WETH9()).deposit{value: amount}();
        }
    }
}