// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../dn404/DN404.sol";
import "../../interfaces/IWETH9.sol";

abstract contract Fallback is DN404 {
    ///
    /// Allows the contract to handle fallback calls
    /// - all the calls that sent to mirror contract are forwarded to this contract
    /// - you can directly call the IERC721 functions using this contract
    ///

    function __calldataload(uint256 offset) private pure returns (uint256 value) {
        /// @solidity memory-safe-assembly
        assembly {
            value := calldataload(offset)
        }
    }
    function __return(uint256 x) private pure {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, x)
            return(0x00, 0x20)
        }
    }

    function _fallback() internal {
        DN404Storage storage $ = _getDN404Storage();
        uint256 fnSelector = __calldataload(0x00) >> 224;

        // `transferFromNFT(address,address,uint256,address)`.
        if (fnSelector == 0xe5eb36c8) {
            _transferFromNFT(
                address(uint160(__calldataload(0x04))), // `from`.
                address(uint160(__calldataload(0x24))), // `to`.
                __calldataload(0x44), // `id`.
                address(uint160(__calldataload(0x64))) // `msgSender`.
            );
            __return(1);
        }
        // `setApprovalForAll(address,bool,address)`.
        if (fnSelector == 0x813500fc) {
            _setApprovalForAll(
                address(uint160(__calldataload(0x04))), // `spender`.
                __calldataload(0x24) != 0, // `status`.
                address(uint160(__calldataload(0x44))) // `msgSender`.
            );
            __return(1);
        }
        // `isApprovedForAll(address,address)`.
        if (fnSelector == 0xe985e9c5) {
            Uint256Ref storage ref = _ref(
                $.operatorApprovals,
                address(uint160(__calldataload(0x04))), // `owner`.
                address(uint160(__calldataload(0x24))) // `operator`.
            );
            __return(ref.value);
        }
        // `ownerOf(uint256)`.
        if (fnSelector == 0x6352211e) {
            __return(uint160(_ownerOf(__calldataload(0x04))));
        }
        // `ownerAt(uint256)`.
        if (fnSelector == 0x24359879) {
            __return(uint160(_ownerAt(__calldataload(0x04))));
        }
        // `approveNFT(address,uint256,address)`.
        if (fnSelector == 0xd10b6e0c) {
            address owner = _approveNFT(
                address(uint160(__calldataload(0x04))), // `spender`.
                __calldataload(0x24), // `id`.
                address(uint160(__calldataload(0x44))) // `msgSender`.
            );
            __return(uint160(owner));
        }
        // `getApproved(uint256)`.
        if (fnSelector == 0x081812fc) {
            __return(uint160(_getApproved(__calldataload(0x04))));
        }
        // `balanceOfNFT(address)`.
        if (fnSelector == 0xf5b100ea) {
            __return(_balanceOfNFT(address(uint160(__calldataload(0x04)))));
        }
        // `totalNFTSupply()`.
        if (fnSelector == 0xe2c79281) {
            __return(_totalNFTSupply());
        }
        // `implementsDN404()`.
        if (fnSelector == 0xb7a94eb8) {
            __return(1);
        }

        revert FnSelectorNotRecognized();
    }
}