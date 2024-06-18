// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IReferrals.sol";

contract Referrals is
    IReferrals,
    Context,
    ReentrancyGuard
{
    ///
    /// Constructor & View Functions
    ///

    constructor(address token_, address defaultReferrer_) {
        _token = token_;
        _defaultReferrer = defaultReferrer_;
    }

    ///
    /// Allows contract to know the bounded token & default referrer
    /// - only the token contract can update the referral prizes
    ///

    address private immutable _token;
    address private immutable _defaultReferrer;
    modifier onlyToken() {
        if (msg.sender != _token) {
            revert Unauthorized();
        }
        _;
    }

    function token() external view returns (address) {
        return _token;
    }
    function defaultReferrer() external view returns (address) {
        return _defaultReferrer;
    }

    ///
    /// Allows users to set a referral code
    ///

    mapping(address => ReferralStats) private _detailsOf;
    mapping(address => address) private _referrers;

    function _getReferrerStats(address referrer) internal view returns (ReferralStats memory) {
        return _detailsOf[referrer];
    }
    function _getReferrerOf(address account) internal view returns (address) {
        address ref = _referrers[account];
        return ref == address(0) ? _defaultReferrer : ref;
    }
    function _setReferral(address account, address referrer) internal {
        // check if the referrer is already set for the account
        address previousReferrer = _getReferrerOf(account);
        if (previousReferrer != _defaultReferrer) {
            revert AlreadyLinked();
        }

        // set the referrer & update the state
        _referrers[account] = referrer;
        _detailsOf[referrer].UsageCount += 1;
    }

    function statsOf(address referrer) external view returns (ReferralStats memory) {
        return _getReferrerStats(referrer);
    }
    function referrerOf(address account) external view returns (address) {
        return _getReferrerOf(account);
    }
    function setReferral(address referrer) external nonReentrant {
        address account = _msgSender();
        if (account == referrer || referrer == address(0)) {
            revert InvalidReferrer();
        }

        _setReferral(account, referrer);
        emit ReferralSet(account, referrer, block.timestamp);
    }

    ///
    /// Allows contract to keep track of the referral prizes
    ///

    function _updatePrize(address account, uint256 amount) internal {
        // get the referrer or use the default referrer
        address referrer = _getReferrerOf(account);
        if (referrer == address(0)) {
            referrer = _defaultReferrer;
        }

        // update the prize & emit the event
        _detailsOf[referrer].Reward += amount;
        emit ReferrerPrizeIncreased(referrer, amount);
    }
    function _updateEthPrize(address account, uint256 amount) internal {
        // get the referrer or use the default referrer
        address referrer = _getReferrerOf(account);
        if (referrer == address(0)) {
            referrer = _defaultReferrer;
        }

        // update the prize & emit the event
        _detailsOf[referrer].EthReward += amount;
        emit ReferrerEthPrizeIncreased(referrer, amount);
    }
    function updatePrize(address account, uint256 amount) external onlyToken {
        _updatePrize(account, amount);
    }
    function updateEthPrize(address account, uint256 amount) external onlyToken {
        _updateEthPrize(account, amount);
    }
}
