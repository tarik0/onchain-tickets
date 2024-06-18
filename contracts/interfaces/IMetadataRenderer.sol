// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IMetadataRenderer {
    enum TicketType {
        Unknown,
        TryAgain,
        Bronze,
        Silver,
        Gold,
        Diamond,
        Emerald
    }

    struct Ticket {
        address owner;
        uint256 tokenId;
        uint256 timestamp;
        TicketType ticketType;
    }

    function renderURI(
        IMetadataRenderer.Ticket memory ticket
    ) external view returns (string memory);
}