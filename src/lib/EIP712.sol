// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract EIP712 {
    bytes32 internal constant TYPE_HASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 internal immutable _hashedName;
    bytes32 internal immutable _hashedVersion;
    uint256 internal immutable _cachedChainId;
    address internal immutable _cachedThis;
    bytes32 internal immutable _cachedDomainSeparator;

    constructor(string memory name, string memory version) {
        _hashedName = keccak256(bytes(name));
        _hashedVersion = keccak256(bytes(version));
        _cachedChainId = block.chainid;
        _cachedThis = address(this);
        _cachedDomainSeparator = _buildDomainSeparator();
    }

    function _domainSeparatorV4() internal view returns (bytes32) {
        if (block.chainid == _cachedChainId && address(this) == _cachedThis) {
            return _cachedDomainSeparator;
        }
        return _buildDomainSeparator();
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(
            abi.encode(TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(this))
        );
    }

    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparatorV4(), structHash));
    }
}

