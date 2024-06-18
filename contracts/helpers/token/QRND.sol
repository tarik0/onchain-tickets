// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@api3/airnode-protocol/contracts/rrp/interfaces/IAirnodeRrpV0.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

abstract contract QRND is
    ReentrancyGuard
{
    ///
    /// Allows users to query the request settings & allows owner to set them.
    /// - tickets are minted using seeds fetched from the Airnode RRP
    ///
    /// requestSettings -> returns the rrp, airnode, sponsor wallet & endpoint id
    ///

    struct AirnodeSettings {
        address AirnodeRrp;
        address Airnode;
        address SponsorWallet;
        bytes32 EndpointIdUint256;
    }
    AirnodeSettings private _airnodeSettings;

    event AirnodeSettingsChanged(AirnodeSettings airnodeSettings);

    function _getAirnodeRrp() internal view returns (address) {
        return _airnodeSettings.AirnodeRrp;
    }
    function _getRequestSettings() internal view returns (AirnodeSettings memory) {
        return _airnodeSettings;
    }
    function _setRequestSettings(AirnodeSettings memory settings) internal {
        IAirnodeRrpV0(settings.AirnodeRrp).setSponsorshipStatus(address(this), true);
        _airnodeSettings = settings;
    }
    function requestSettings() external view returns (AirnodeSettings memory) {
        return _getRequestSettings();
    }

    ///
    /// Allows contract to request seeds for token ids
    /// - contract sends an Airnode RRP request to fetch QRND seeds
    ///
    /// fulfillUint256 -> callback function to receive the seed
    /// _requestSeedForTokenIds -> allows contract to request seeds for token ids
    ///

    struct SeedRequestWithRange {
        uint256 fromId;
        uint256 toId;
        uint256 timestamp;
        bool hasReferral;
    }
    struct SeedRequestWithIds {
        uint256[] tokenIds;
        uint256 timestamp;
        bool hasReferral;
    }

    struct SeedResponse {
        uint256 seed;
        uint256 timestamp;
        bool hasReferral;
    }

    mapping(bytes32 => SeedRequestWithRange) private _expectedRequestsWithRange;
    mapping(bytes32 => SeedRequestWithIds) private _expectedRequestsWithIds;

    mapping(bytes32 => SeedResponse) private _requestToResponse;
    mapping(uint256 => bytes32) private _tokenIdToRequestId;

    error UnexpectedRequest();

    event SeedRequestedForRange(uint256 fromId, uint256 toId, uint256 probabilityTimestamp);
    event SeedRequestedForIds(uint256[] tokenIds, uint256 probabilityTimestamp);

    // sets _minConfirmations to 1
    // encode([{ name: '_minConfirmations', type: 'string32', value: '1' }]);
    bytes private constant _PARAMS = hex"31730000000000000000000000000000000000000000000000000000000000005f6d696e436f6e6669726d6174696f6e730000000000000000000000000000003100000000000000000000000000000000000000000000000000000000000000";

    function _hasReferral(address account) internal view virtual returns (bool);
    function _makeRequest(bytes4 selector) internal returns (bytes32) {
        // make request
        AirnodeSettings memory settings = _airnodeSettings;
        return IAirnodeRrpV0(settings.AirnodeRrp).makeFullRequest(
            settings.Airnode,
            settings.EndpointIdUint256,
            address(this),
            settings.SponsorWallet,
            address(this),
            selector,
            _PARAMS
        );
    }
    function _requestSeedForRange(uint256 fromId, uint256 toId, uint256 probabilityTimestamp) internal {
        // make request
        bytes32 requestId = _makeRequest(this.fulfillWithRange.selector);

        // iterate over token ids in chunk
        for (uint256 tokenId = fromId; tokenId < toId; tokenId++) {
            // store token id to request id
            _tokenIdToRequestId[tokenId] = requestId;
        }

        // store request
        _expectedRequestsWithRange[requestId] = SeedRequestWithRange(
            fromId,
            toId,
            probabilityTimestamp,
            _hasReferral(msg.sender)
        );
        emit SeedRequestedForRange(fromId, toId, probabilityTimestamp);
    }
    function _requestSeedForIds(uint256[] memory tokenIds, uint256 probabilityTimestamp) internal {
        // make request
        bytes32 requestId = _makeRequest(this.fulfillWithIds.selector);

        // iterate over token ids
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] != 0) {
                // store token id to request id
                _tokenIdToRequestId[tokenIds[i]] = requestId;
            }
        }

        // store request
        _expectedRequestsWithIds[requestId] = SeedRequestWithIds(
            tokenIds,
            probabilityTimestamp,
            _hasReferral(msg.sender)
        );
        emit SeedRequestedForIds(tokenIds, probabilityTimestamp);
    }
    function _normalizeRawSeed(uint256 rawSeed) internal view virtual returns (uint256) {
        if (rawSeed < type(uint8).max) {
            return type(uint8).max;
        }
        return rawSeed;
    }
    function _checkAirnodeRrp() internal view {
        if (msg.sender != _getAirnodeRrp()) {
            revert UnexpectedRequest();
        }
    }
    function fulfillWithRange(bytes32 requestId, bytes calldata data) external {
        // validate request
        _checkAirnodeRrp();

        // decode seed
        uint256 rawSeed = abi.decode(data, (uint256));
        rawSeed = _normalizeRawSeed(rawSeed); // limits the seed to min 255

        // set request's response
        SeedRequestWithRange memory seedRequest = _expectedRequestsWithRange[requestId];
        _requestToResponse[requestId] = SeedResponse(rawSeed, seedRequest.timestamp, seedRequest.hasReferral);

        // call after hook
        _afterFulfillWithRange(rawSeed, seedRequest.fromId, seedRequest.toId, seedRequest.hasReferral);
        delete _expectedRequestsWithRange[requestId];  // remove request
    }
    function fulfillWithIds(bytes32 requestId, bytes calldata data) external {
        // validate request
        _checkAirnodeRrp();

        // decode seed
        uint256 rawSeed = abi.decode(data, (uint256));
        rawSeed = _normalizeRawSeed(rawSeed); // limits the seed to 0 ~ 2**32

        // set request's response
        SeedRequestWithIds memory seedRequest = _expectedRequestsWithIds[requestId];
        _requestToResponse[requestId] = SeedResponse(rawSeed, seedRequest.timestamp, seedRequest.hasReferral);

        // call after hook
        _afterFulfillWithIds(rawSeed, seedRequest.tokenIds, seedRequest.hasReferral);
        delete _expectedRequestsWithIds[requestId];  // remove request
    }

    ///
    /// Helper Functions
    ///

    function _resetRequestForTokenId(uint256 tokenId) internal {
        delete _tokenIdToRequestId[tokenId];
    }
    function _setSeedForTokenId(bytes32 reqId, uint256 tokenId, SeedResponse memory res) internal {
        _requestToResponse[reqId] = res;
        _tokenIdToRequestId[tokenId] = reqId;
    }
    function _seedForTokenId(uint256 tokenId) internal view returns (uint256, uint256, bool) {
        // get request id for token id
        bytes32 requestId = _tokenIdToRequestId[tokenId];
        if (requestId == 0) {
            return (0, 0, false);
        }

        // get seed response
        SeedResponse memory seedResponse = _requestToResponse[requestId];
        return (_normalizeSeed(seedResponse.seed, tokenId), seedResponse.timestamp, seedResponse.hasReferral);
    }
    function _requestIdForTokenId(uint256 tokenId) internal view returns (bytes32) {
        return _tokenIdToRequestId[tokenId];
    }
    function _isRequestSent(bytes32 requestId) internal view returns (bool) {
        if (requestId == 0) {
            return false;
        }
        return _expectedRequestsWithIds[requestId].timestamp > 0 || _expectedRequestsWithRange[requestId].timestamp > 0;
    }
    function _isRequestFailed(bytes32 requestId, bool isPending) internal view returns (bool) {
        // should have request
        // should not have response
        // should not be pending
        return _requestToResponse[requestId].timestamp == 0 && !isPending;
    }
    function _isRequestPending(bytes32 requestId) internal view returns (bool) {
        // should have request
        // should await response
        return _isRequestSent(requestId) &&
            IAirnodeRrpV0(_getAirnodeRrp()).requestIsAwaitingFulfillment(requestId);
    }

    ///
    /// Hook
    ///

    function _afterFulfillWithRange(uint256 seed, uint256 fromId, uint256 toId, bool hasRef) internal virtual;
    function _afterFulfillWithIds(uint256 seed, uint256[] memory ids, bool hasRef) internal virtual;
    function _normalizeSeed(uint256 rawSeed, uint256 tokenId) internal virtual view returns (uint256);
}