// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Test.sol";

import "src/Contract.sol";
import "partybid/PartyBid.sol";
import "partybid/PartyBidFactory.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    uint256 balanceBefore;

    // the noun we're testing with
    uint256 constant noun11 = 11;
    // https://etherscan.io/tx/0x14292770d0867c9d78234a11a7d5afe558dab4acf7269eb600674a034c54c350#eventlog
    uint256 constant noun11Vault = 275;
    uint256 constant noun11PartyVault = 1278;
    // the market wrapper creator wants some rent
    address constant rentAddress = address(0x1234);
    uint256 constant rentBasisPoints = 200;

    address constant bidder = address(0xbbbb);
    address constant curator = address(0xcccc);
    address constant enemy = address(0xdddd);

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

        // some people contribute to the auction
        hoax(bidder, 200 ether);
        bid.contribute{value: 200 ether}();

        // save the balance before getting the change back
        balanceBefore = address(bidder).balance;

        // bid!
        vm.prank(bidder);
        bid.bid();

        // add some labels for traces to be nicer
        vm.label(_bid, "PartyBid");
        vm.label(rentAddress, "Rent");
        vm.label(bidder, "Bidder");
        vm.label(curator, "Curator");
        vm.label(address(vault), "Vault");
    }

    // helper to fast forward to the end of the auction
    function endAuction() private {
        uint256 endTime = vault.auctionEnd();
        vm.warp(endTime);
        bid.finalize();
    }

    function testCanSaveNoun11() public {
        endAuction();

        // the partydao deployed vault owns the token
        IERC20 partyVault = IERC20(bid.tokenVaultFactory().vaults(noun11PartyVault));
        assertEq(nouns.ownerOf(noun11), address(partyVault));


        bid.claim(bidder);

        // check that we own most of the supply, minus the fees
        assertGt(partyVault.balanceOf(bidder), 954 * partyVault.totalSupply() / 1000);

        uint256 balanceAfter = address(bidder).balance;

        // 200 - ~109 ETH = 91 eth received back
        assertGt(balanceAfter - balanceBefore, 91 ether);
    }

    function testOutbid() public {
        vm.label(enemy, "enemy");
        hoax(enemy);

        // they outbid us directly on the vault
        vault.bid{value: 125 ether}();

        // end the auction
        endAuction();

        // they now own the noun
        assertEq(nouns.ownerOf(noun11), enemy);

        // but at least we can get our ETH back
        bid.claim(bidder);
        // for some reason we only get 94 ETH back?
        assertEq(bidder.balance, 200 ether);
    }
}
