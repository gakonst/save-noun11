// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "partybid/market-wrapper/IMarketWrapper.sol";

// The fractional factory
interface FractionalFactory {
    function vaults(uint256) external view returns (FractionalVault);
}

// The state of an auction
enum State { inactive, live, ended, redeemed }

// A specific fractional auction
interface FractionalVault {
    function start() payable external;
    function bid() payable external;
    function end() external;

    function auctionEnd() external view returns (uint256);
    function auctionState() external view returns (State);
    function winning() external view returns (address);
    function reservePrice() external view returns (uint256);
    function livePrice() external view returns (uint256);
}

interface FractionalSettings {
    function minBidIncrease() external view returns (uint256);
}

// WETH
// address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;


contract FractionalMarketWrapper is IMarketWrapper {
    // https://github.com/fractional-company/contracts#mainnet
    FractionalFactory public constant factory = FractionalFactory(0x85Aa7f78BdB2DE8F3e0c0010d99AD5853fFcfC63);
    FractionalSettings public constant settings = FractionalSettings(0xE0FC79183a22106229B84ECDd55cA017A07eddCa);

    // if the contract has any WETH, unwrap it into ETH?
    function bid(uint256 auctionId, uint256 bidAmount) external {
        FractionalVault vault = factory.vaults(auctionId);
        if (vault.auctionState() == State.inactive) {
            vault.start{value: bidAmount}();
        } else {
            vault.bid{value: bidAmount}();
        }
    }

    function finalize(uint256 auctionId) external override {
        factory.vaults(auctionId).end();
    }

    function getCurrentHighestBidder(uint256 auctionId) external view override returns (address) {
        return factory.vaults(auctionId).winning();
    }

    function isFinalized(uint256 auctionId) external view override returns (bool) {
        return factory.vaults(auctionId).auctionState() == State.ended;
    }

    function getMinimumBid(uint256 auctionId) external view override returns (uint256) {
        FractionalVault vault = factory.vaults(auctionId);
        uint256 price = vault.livePrice();

        // use the reserve price if this is the first bid
        if (price == 0) {
            return vault.reservePrice();
        } else {
            // bump the price just enough
            uint256 pctIncrease = settings.minBidIncrease() + 1001;
            // divide by 1000 to re-normalize the pct
            return price * pctIncrease / 1000;
        }
    }

    function auctionIdMatchesToken(
        uint256 auctionId,
        // unused params
        address, uint256
    ) public view override returns (bool) {
        return address(factory.vaults(auctionId)) != address(0x0);
    }
}
