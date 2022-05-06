# SaveNoun11

Fractional adapter for PartyBid using Foundry. 

Unfortunately hits a limitation when getting outbid:

Fractional [reimburses contributors in WETH](https://github.com/fractional-company/contracts/blob/master/src/ERC721TokenVault.sol#L399) if there's no fallback function implemented. This means that if a PartyBid gets outbid, it receives WETH, not ETH. PartyBid does not have a way to "convert" that WETH to ETH to re-bid, so the WETH is ~stuck ¯\_(ツ)_/¯.

This should be fixable by just adding a `receive() external payable {}` to the PartyBid contracts, or by even more explicitly
adding a `convertWETHtoETH` method which ideally gets automatically called on each bid.

## Testing

Add your RPC url below and run:

```
`forge t --fork-url $ETH_RPC_URL --fork-block-number 14725939 -vvvvv`
```
