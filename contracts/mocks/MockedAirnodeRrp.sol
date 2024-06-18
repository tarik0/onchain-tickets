// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../interfaces/ITickets404.sol";

contract MockedAirnodeRrp {
    uint256 internal _counter = 0;
    uint256 public lastGasUsed;
    mapping(bytes32 => address payable) internal _reqToRequester;
    mapping(bytes32 => uint256) internal _reqToCounter;

    ///
    /// Helpers
    ///

    function nextRequestIds(uint256[] calldata tokenIds) external view returns (bytes32[] memory) {
        bytes32[] memory requestIds = new bytes32[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            requestIds[i] = nextRequestId();
        }
        return requestIds;
    }
    function nextRequestId() public view returns (bytes32) {
        return bytes32(uint256(keccak256(abi.encodePacked(_counter))));
    }
    function nextRandomSeed() public view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(_counter)));
    }
    function nextRandomSeeds(uint256 length) public view returns (uint256[] memory) {
        uint256[] memory seeds = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            seeds[i] = nextRandomSeed();
        }
        return seeds;
    }
    function normalizeSeed(uint256 rawSeed, uint256 tokenId) external pure returns (uint256) {
        uint256 tmp = rawSeed ^ tokenId;
        return tmp % type(uint32).max;  // limit to 32 bits
    }

    function mockFulfillWithIds(bytes32 requestId) external {
        ITickets404(_reqToRequester[requestId]).fulfillWithIds(
            requestId,
            abi.encode(uint256(keccak256(abi.encodePacked(_reqToCounter[requestId]))))
        );
        delete _reqToRequester[requestId];
        delete _reqToCounter[requestId];
    }
    function mockFulfillWithRange(bytes32 requestId) external {
        ITickets404(_reqToRequester[requestId]).fulfillWithRange(
            requestId,
            abi.encode(uint256(keccak256(abi.encodePacked(_reqToCounter[requestId]))))
        );
        delete _reqToRequester[requestId];
        delete _reqToCounter[requestId];
    }
    function mockFail(bytes32 requestId) external {
        delete _reqToRequester[requestId];
        delete _reqToCounter[requestId];
    }

    ///
    /// Mocked Airnode RRP
    ///

    function setSponsorshipStatus(address requester, bool sponsorshipStatus) external {}

    function _requestIsPending(bytes32 requestId) internal view returns (bool) {
        return _reqToRequester[requestId] != address(0) && _reqToCounter[requestId] == 0;
    }
    function requestIsAwaitingFulfillment(bytes32 requestId) external view returns (bool) {
        return _requestIsPending(requestId);
    }

    function makeFullRequest(
        address,
        bytes32,
        address,
        address,
        address,
        bytes4,
        bytes calldata
    ) external returns (bytes32 requestId) {
        // generate a random requestId
        requestId = nextRequestId();
        _reqToRequester[requestId] = payable(msg.sender);
        _reqToCounter[requestId] = _counter;
        _counter++;

        return requestId;
    }
}