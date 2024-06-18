// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@quant-finance/solidity-datetime/contracts/DateTime.sol";
import "./interfaces/IMetadataRenderer.sol";
import "./helpers/renderer/RendererStyle.sol";
import "./interfaces/IRendererStyle.sol";

contract MetadataRenderer is IMetadataRenderer {
    ///
    /// Helpers
    ///

    function renderSVG(
        IMetadataRenderer.Ticket memory ticket
    ) public view returns (string memory svgImg) {
        TicketType ticketType = ticket.ticketType;

        // Background & Decoration
        {
            svgImg = string.concat(
                '<svg width="500" height="225" viewBox="0 0 800 360" xmlns="http://www.w3.org/2000/svg"><defs>',
                _style.getFont(),
                _style.getFilter(),
                ticketType == TicketType.Bronze
                    ? '<linearGradient id="gradient"><stop offset="0%" stop-color="#CD7F32" /><stop offset="10%" stop-color="#E9C2A6" /><stop offset="50%" stop-color="#CD7F32" /><stop offset="90%" stop-color="#E9C2A6" /><stop offset="100%" stop-color="#CD7F32"/></linearGradient>'
                    : ticketType == TicketType.Silver
                    ? '<linearGradient id="gradient"><stop offset="0%" stop-color="#C0C0C0" /><stop offset="10%" stop-color="#F1F1F1" /><stop offset="50%" stop-color="#C0C0C0" /><stop offset="90%" stop-color="#F1F1F1" /><stop offset="100%" stop-color="#C0C0C0"/></linearGradient>'
                    : ticketType == TicketType.Gold
                    ? '<linearGradient id="gradient"><stop offset="0%" stop-color="#BF953F" /><stop offset="10%" stop-color="#FCF6BA" /><stop offset="50%" stop-color="#BF953F" /><stop offset="90%" stop-color="#FCF6BA" /><stop offset="100%" stop-color="#BF953F"/></linearGradient>'
                    : ticketType == TicketType.Diamond
                    ? '<linearGradient id="gradient"><stop offset="0%" stop-color="#B9F2FF" /><stop offset="10%" stop-color="#E0FFFF" /><stop offset="50%" stop-color="#B9F2FF" /><stop offset="90%" stop-color="#E0FFFF" /><stop offset="100%" stop-color="#B9F2FF"/></linearGradient>'
                    : ticketType == TicketType.Emerald
                    ? '<linearGradient id="gradient"><stop offset="0%" stop-color="#50C878" /><stop offset="10%" stop-color="#A6DCAF" /><stop offset="50%" stop-color="#50C878" /><stop offset="90%" stop-color="#A6DCAF" /><stop offset="100%" stop-color="#50C878"/></linearGradient>'
                    : ticketType == TicketType.TryAgain
                    ? '<linearGradient id="gradient"><stop offset="0%" stop-color="#D3D3D3" /><stop offset="100%" stop-color="#D3D3D3" /></linearGradient>'
                    : '<linearGradient id="gradient"><stop offset="0%" stop-color="#fff" /><stop offset="100%" stop-color="#fff" /></linearGradient>',
                _style.getTicketPath(),
                _style.getHeader()
            );
        }

        // Header & Token ID
        {
            (uint256 y, uint256 m, uint256 d) = DateTime.timestampToDate(
                (ticket.timestamp > 0 && ticket.ticketType != TicketType.TryAgain)
                    ? ticket.timestamp + 40 days // tickets expire after 40 days (2.5% per day)
                    : block.timestamp
            );

            svgImg = string.concat(
                svgImg,
                ticketType == TicketType.Bronze
                    ? '<text x="105" y="180" font-family="Cantata" font-size="64">BRONZE TICKET</text>'
                    : ticketType == TicketType.Silver
                    ? '<text x="125" y="180" font-family="Cantata" font-size="64">SILVER TICKET</text>'
                    : ticketType == TicketType.Gold
                    ? '<text x="102" y="180" font-family="Cantata" font-size="64">GOLDEN TICKET</text>'
                    : ticketType == TicketType.Diamond
                    ? '<text x="75" y="180" font-family="Cantata" font-size="64">DIAMOND TICKET</text>'
                    : ticketType == TicketType.Emerald
                    ? '<text x="78" y="180" font-family="Cantata" font-size="64">EMERALD TICKET</text>'
                    : ticketType == TicketType.TryAgain
                    ? '<text x="202" y="180" font-family="Cantata" font-size="64">TRY AGAIN</text>'
                    : '<text x="160" y="180" font-family="Cantata" font-size="64">UNREVEALED</text>',
                '<text x="50" y="260" font-family="Cantata" font-size="19">Expire Date</text><text x="450" y="260" font-family="Cantata" font-size="19">Serial</text>',
                '<text x="50" y="300" font-family="Cantata" font-size="30">',
                Strings.toString(d),
                "-",
                Strings.toString(m),
                "-",
                Strings.toString(y),
                "</text>"
            );
        }

        // Token ID
        {
            svgImg = string.concat(
                svgImg,
                '<text x="450" y="300" font-family="Cantata" font-size="30">#',
                Strings.toString(ticket.tokenId),
                "</text>"
            );
        }

        // Footer
        {
            svgImg = string.concat(
                svgImg,
                '<text x="205" y="348" font-family="Cantata" font-size="13">Owner: ',
                Strings.toHexString(uint160(ticket.owner), 20),
                "</text>",
                "</g>",
                '<rect x="0" y="0" width="800" height="360" clip-path="url(#ticket)" filter="url(#noise)" opacity=".4" />',
                "</svg>"
            );
        }
    }

    function renderSVGBase64(
        IMetadataRenderer.Ticket memory ticket
    ) public view returns (string memory) {
        string memory base64EncodedSVG = Base64.encode(
            bytes(renderSVG(ticket))
        );
        return
            string(
                abi.encodePacked("data:image/svg+xml;base64,", base64EncodedSVG)
            );
    }

    function renderAttributes(
        IMetadataRenderer.TicketType ticketType
    ) public pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '[{"trait_type":"Ticket Type","value":"',
                    ticketType == TicketType.Bronze
                        ? "Bronze"
                        : ticketType == TicketType.Silver
                        ? "Silver"
                        : ticketType == TicketType.Gold
                        ? "Gold"
                        : ticketType == TicketType.Diamond
                        ? "Diamond"
                        : ticketType == TicketType.Emerald
                        ? "Emerald"
                        : ticketType == TicketType.TryAgain
                        ? "Try Again"
                        : "Unrevealed",
                    '"}]'
                )
            );
    }

    ///
    /// Renderer
    ///

    function renderURI(
        Ticket memory ticket
    ) external view override returns (string memory) {
        string memory json = Base64.encode(
            bytes(
                string.concat(
                    '{"name":"',
                    "ONCHAIN TICKETS #",
                    Strings.toString(ticket.tokenId),
                    '","description":"',
                    "Innovative trade-to-earn experience with quantum-resilient randomness based on quantum phenomena, offering a fully onchain, transparent lottery on Base.",
                    '","attributes":',
                    renderAttributes(ticket.ticketType),
                    ',"image": "',
                    renderSVGBase64(ticket),
                    '"}'
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    ///
    /// Constructor
    ///

    IRendererStyle public _style;

    constructor(IRendererStyle style) {
        _style = style;
    }
}
