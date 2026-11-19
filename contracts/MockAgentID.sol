// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title MockAgentID (TESTNET ONLY)
/// @notice A tiny stand-in for the SPACE ID "AI" Agent ID registry, used only on
///         BSC Testnet where the real registry is not deployed. Anyone can mint a
///         mock ID so the check-in flow can be tested end to end. Never deploy this
///         on mainnet: AgentCheckIn on mainnet points at the real registry
///         0x60b9262456de011f7d15a54cdd8c48baaa8b022f.
contract MockAgentID {
    string public name = "Mock Agent ID (testnet only)";
    string public symbol = "mAI";

    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _owners;
    uint256 private _nextId = 1;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /// @notice Mint one mock Agent ID to `to`. Open on purpose: this is a test prop.
    function mint(address to) external returns (uint256 tokenId) {
        tokenId = _nextId++;
        _owners[tokenId] = to;
        _balances[to] += 1;
        emit Transfer(address(0), to, tokenId);
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return _owners[tokenId];
    }
}
