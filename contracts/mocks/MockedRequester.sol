// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@api3/airnode-protocol/contracts/rrp/interfaces/IAirnodeRrpV0.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockedRequester is
    Ownable
{
    address internal _airnodeRrp;
    address internal _airnode;
    address internal _sponsorWallet;
    bytes32 internal _endpointIdUint256;

    event Requested(bytes32 requestId);

    constructor() {}

    function setSettings(
        address airnodeRrp,
        address airnode,
        address sponsorWallet,
        bytes32 endpointIdUint256
    ) external onlyOwner {
        _airnodeRrp = airnodeRrp;
        _airnode = airnode;
        _sponsorWallet = sponsorWallet;
        _endpointIdUint256 = endpointIdUint256;

        IAirnodeRrpV0(_airnodeRrp).setSponsorshipStatus(address(this), true);
    }

    struct Request {
        uint256 fromId;
        uint256 toId;
        uint256 timestamp;
        bool hasReferral;
    }

    struct Response {
        uint256 rawSeed;
        uint256 timestamp;
        bool hasReferral;
    }

    function requestUint256(uint256 tokenIdCount) external onlyOwner {
        bytes32 requestId = IAirnodeRrpV0(
            _airnodeRrp
        ).makeFullRequest(
            _airnode,
            _endpointIdUint256,
            address(this),
            _sponsorWallet,
            address(this),
            this.fulfillUint256.selector,
            ""
        );

        _expectedRequests[requestId] = Request(0, tokenIdCount, block.timestamp, false);

        emit Requested(requestId);
    }

    mapping(bytes32 => Request) private _expectedRequests;
    mapping(bytes32 => Response) private _requestToResponse;
    uint256 private _totalProbability;

    function fulfillUint256(bytes32 requestId, bytes calldata data) external {
        // validate request
        Request memory seedRequest = _expectedRequests[requestId];
        if (msg.sender != _airnodeRrp) {
            revert();
        }

        // decode seed
        uint256 rawSeed = abi.decode(data, (uint256));

        // set request's response
        _requestToResponse[requestId] = Response(rawSeed, seedRequest.timestamp, seedRequest.hasReferral);

        // iterate over token ids
        for (uint256 i = seedRequest.fromId; i < seedRequest.toId; i++) {
           _totalProbability += (rawSeed ^ i) % type(uint32).max;
        }
        delete _expectedRequests[requestId];
    }
}