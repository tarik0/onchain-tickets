// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRendererStyle {
    function getHeader() external pure returns (string memory);
    function getTicketPath() external pure returns (string memory);
    function getFilter() external pure returns (string memory);
    function getFont() external pure returns (string memory);
}
