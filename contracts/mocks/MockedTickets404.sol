// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Tickets404.sol";

contract MockedTickets404 is
    Tickets404
{
    constructor() {
        _setInitialProbabilities(Probabilities({
            Bronze: 10,
            Silver: 20,
            Gold: 30,
            Diamond: 40,
            Emerald: 50
        }));
    }

    uint256 private _period = 10 seconds;

    function _decreasePeriod() internal override view returns (uint256) {
        return _period;
    }

    function setPeriod(uint256 period) external {
        _period = period;
    }

    function name() public pure override (Base, DN404) returns (string memory) {
        return "Launch today! Follow us @onchaintickets";
    }
    function symbol() public pure override (Base, DN404) returns (string memory) {
        return "TICKET_TEST";
    }

    function setTicketSeed(uint256 rawSeed, uint256 tokenId, bool newHasRef) external {
        // deregister the ticket
        (uint256 oldSeed, uint256 timestamp, bool hasRef) = _seedForTokenId(tokenId);
        if (timestamp != 0) {
            _deregisterTicket(oldSeed, timestamp, hasRef);
        } else {
            timestamp = _lastSnapshotTimestamp();
        }

        // override the seed
        bytes32 reqId = bytes32(uint256(keccak256(abi.encodePacked(block.timestamp, rawSeed, tokenId))));
        _setSeedForTokenId(reqId, tokenId, SeedResponse(rawSeed, timestamp, newHasRef));

        // register the ticket
        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;
        _registerTicketsWithIds(rawSeed, ids, timestamp, hasRef);
    }

    function getTicketSeed(uint256 tokenId) external view returns (uint256 s, uint256 t, bool r) {
        (s, t, r) = _seedForTokenId(tokenId);
    }
    function isTicketPending(uint256 tokenId) external view returns (bool) {
        bytes32 reqId = _requestIdForTokenId(tokenId);
        return _isRequestPending(reqId);
    }
    function isTicketFailed(uint256 tokenId) external view returns (bool) {
        bytes32 reqId = _requestIdForTokenId(tokenId);
        return _isRequestFailed(reqId, _isRequestPending(reqId));
    }
    function requestForTokenId(uint256 tokenId) external view returns (bytes32) {
        return _requestIdForTokenId(tokenId);
    }
}