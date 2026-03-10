// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/AresErrors.sol";

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) revert AresErrors.ReentrantCall();
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}
