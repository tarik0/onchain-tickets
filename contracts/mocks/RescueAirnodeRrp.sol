// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../interfaces/ITickets404.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RescueAirnodeRrp is Ownable {
    uint256 internal _counter = 0;
    mapping(bytes32 => bool) internal _fulfilled;
    mapping(bytes32 => address payable) internal _fulfillReceiver;

    function setSponsorshipStatus(address requester, bool sponsorshipStatus) external {}

    function requestIsAwaitingFulfillment(bytes32 requestId)
        external
        view
        returns (bool isAwaitingFulfillment)
    {
        return !_fulfilled[requestId];
    }

    function nextRequestId() public view returns (bytes32) {
        return bytes32(uint256(keccak256(abi.encodePacked(_counter))));
    }

    function makeFullRequest(
        address,
        bytes32,
        address,
        address,
        address fulfillAddress,
        bytes4,
        bytes calldata
    ) external returns (bytes32 requestId) {
        requestId = nextRequestId();
        _fulfilled[requestId] = false;
        _fulfillReceiver[requestId] = payable(fulfillAddress);
        _counter++;
    }

    function mockFulfillWithIds(bytes32 requestId, bytes calldata data) external onlyOwner {
        ITickets404(_fulfillReceiver[requestId]).fulfillWithIds(
            requestId,
            data
        );
        _fulfilled[requestId] = true;
        delete _fulfillReceiver[requestId];
    }
    function mockFulfillWithRange(bytes32 requestId, bytes calldata data) external onlyOwner {
        ITickets404(_fulfillReceiver[requestId]).fulfillWithRange(
            requestId,
            data
        );
        _fulfilled[requestId] = true;
        delete _fulfillReceiver[requestId];
    }
}