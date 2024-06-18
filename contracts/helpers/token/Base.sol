// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/IMetadataRenderer.sol";
import "../../dn404/DN404.sol";

abstract contract Base is
    DN404,
    Ownable
{
    ///
    /// Allows the contract to set the metadata renderer & referrals contract
    ///

    address private _renderer;
    address private _referrals;

    function _setRenderer(address renderer_) internal {
        _renderer = renderer_;
    }
    function _setReferrals(address referrals_) internal {
        _referrals = referrals_;
    }
    function _getRenderer() internal view returns (address) {
        return _renderer;
    }
    function _getReferrals() internal view returns (address) {
        return _referrals;
    }
    function setHelperContracts(address renderer_, address referrals_) external onlyOwner {
        _setRenderer(renderer_);
        _setReferrals(referrals_);
    }

    ///
    /// Allows users to query basic information
    /// - do i really need to explain this?
    /// - oh yeah, there are also some ERC721 functions as well
    ///

    function name() public pure virtual override returns (string memory) {
        return "Onchain Tickets";
    }
    function symbol() public pure virtual override returns (string memory) {
        return "TICKET";
    }
    function helperContracts() external view returns (address renderer, address referrals) {
        return (_renderer, _referrals);
    }
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return _tokenURI(tokenId);
    }
}
