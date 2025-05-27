// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockSablierNFT {
    address public owner;
    uint8 public status;
    uint256 public tokenId;
    bool public withdrawn;

    constructor(address _owner, uint8 _status, uint256 _tokenId) {
        owner = _owner;
        status = _status;
        tokenId = _tokenId;
    }

    function ownerOf(uint256 id) external view returns (address) {
        require(id == tokenId, "Invalid tokenId");
        return owner;
    }

    function statusOf(uint256 id) external view returns (uint8) {
        require(id == tokenId, "Invalid tokenId");
        return status;
    }

    function withdrawMax(uint256 id, address to) external returns (uint128) {
        require(id == tokenId, "Invalid tokenId");
        require(msg.sender == owner, "Not owner");
        require(status == 2, "Not withdrawable");
        require(!withdrawn, "Already withdrawn");
        withdrawn = true;
        return 5;
    }
}
