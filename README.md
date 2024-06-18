# Tickets404 - Onchain Lottery

An DN404 project to create a lottery contract that is fully onchain and decentralized.
It uses API3 QRND to generate quantum resistant random numbers.

## Deployment

* Update `hardhat.config.ts` with the correct network settings. 
* Update `scripts/deploy.ts` with the correct values.
* Run `npx hardhat run scripts/deploy.ts` to deploy the contract to the desired network.

## Initial Setup

* Add liquidity to a pool on Uniswap or Sushiswap. 
* Update the parameters in `scripts/initialize.ts` with the correct values.
* 0.001 ETH is required to initialize the contract. (for the QRND sponsor)
* Run `npx hardhat run scripts/initialize.ts` to initialize the contract with the correct values.

## Fetch Details

* Update the parameters in `scripts/fetch-details.ts` with the correct values.
* Use `npx hardhat run scripts/fetch-details.ts` to interact with the contract.

## Update Renderer

* Update the parameters in `scripts/update-renderer.ts` with the correct values.
* Use `npx hardhat run scripts/update-renderer.ts` to update the renderer.
* This will update the renderer with the latest deployed contract address.

## Testing

* Run `npx hardhat test` to run the tests.