// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Test.sol";

import "src/Contract.sol";
import "partybid/PartyBid.sol";
import "partybid/PartyBidFactory.sol";

interface Nouns {
    function ownerOf(uint256) external view returns (address);
}

contract ContractTest is Test {
    // Mainnet contracts
    PartyBidFactory constant partyFactory = PartyBidFactory(0x0accf637e4F05eeA8B1D215C8C9e9E576dC63D33);
    PartyBid constant party = PartyBid(0x18B9F4aD986A0E0777a2E1A652a4499C8EE3E077);
    Nouns constant nouns = Nouns(0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03);
    FractionalVault vault;

    // the fractional wrapper
    FractionalMarketWrapper fractional;
    PartyBid bid;

    // the noun we're testing with
    uint256 constant noun11 = 11;
    // https://etherscan.io/tx/0x14292770d0867c9d78234a11a7d5afe558dab4acf7269eb600674a034c54c350#eventlog
    uint256 constant noun11Vault = 275;
    // the market wrapper creator wants some rent
    address constant rentAddress = address(0x1234);
    uint256 constant rentBasisPoints = 200;

    // enable forge-std storage overwrites
    using stdStorage for StdStorage;

    function setUp() public {
        // deploy the market wrapper
        fractional = new FractionalMarketWrapper();
        vault = fractional.factory().vaults(noun11Vault);

        // override the `curator` address on the fractional vaults
        // to be non-zero. the currently deployed Fractional version
        // does not have the `if curator != 0x0` check, and that causes
        // openzeppelin to choke on transfers to 0x0.
        // https://github.com/fractional-company/contracts/commit/5003fc2189a5998dcfaddcb83ddcbbb53ec9c628
        stdstore.target(address(vault))
            .sig(FractionalVault.curator.selector)
            .checked_write(address(0x01));

        // start the party
        address _bid = partyFactory.startParty(
            address(fractional), // market wrapper
            address(nouns), // nftcontract
            // these can be the same for Fractional, given that we go via the factory
            noun11, // tokenId
            noun11Vault, // auctionId
            Structs.AddressAndAmount({ addr: rentAddress, amount: rentBasisPoints }),
            Structs.AddressAndAmount({ addr: address(0), amount: 0 }),
            "Noun11",
            "N11"
        );
        bid = PartyBid(_bid);
    }

    function testCanSaveNoun11() public {
        // some people contribute to the auction
        bid.contribute{value: 200 ether}();

        // bid!
        bid.bid();

    function endAuction() private {
        uint256 endTime = vault.auctionEnd();
        vm.warp(endTime);

        // wrap it up
        bid.finalize();
    }

    function testCanSaveNoun11() public {
        endAuction();
        // assertEq(nouns.ownerOf(noun11, address(bid));
    }

    // TODO: Test refunds with WETH edge case
}
