import { ethers } from "hardhat";
import fs from "fs";
import {fee} from "../../test/util/uniswap";

///
/// Uniswap Artifacts
///

type ContractJson = { abi: any; bytecode: string };
export const uniswapArtifacts: { [name: string]: ContractJson } = {
    WETH9: require("./../../test/util/artifacts/WETH9.json"),
    SwapRouter02: require("./../../test/util/artifacts/SwapRouter02.json"),
};

///
/// Sells tokens after the trade starts.
/// - tries to sell all the tokens.
///

const SELLER_WALLET = process.env.SELLER_WALLET;
const SWAP_ROUTER02 = "0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4";

async function main() {
    if (!SELLER_WALLET) {
        console.error("SELLER_WALLET is not set");
        process.exit(1);
    }

    // read deployed contracts from deployments/chainId.json
    const chainId = (await ethers.provider.getNetwork()).chainId;
    const deployments = JSON.parse(fs.readFileSync(`deployments/${chainId}.json`).toString());
    if (!deployments.Tickets404) {
        console.error(`Tickets404 contract not found in deployments/${chainId}.json`);
        process.exit(1);
    }
    if (!deployments.IS_INITIALIZED) {
        console.error(`Contract not initialized in deployments/${chainId}.json`);
        process.exit(1);
    }
    if (!deployments.IS_TRADE_ENABLED) {
        console.error(`Trade not enabled in deployments/${chainId}.json`);
        process.exit(1);
    }

    // get the contracts and the buyer wallet
    const token = await ethers.getContractAt("Tickets404", deployments.Tickets404);
    const seller = new ethers.Wallet(SELLER_WALLET, ethers.provider);
    const swapRouter02 = new ethers.Contract(SWAP_ROUTER02, uniswapArtifacts.SwapRouter02.abi, seller);

    // get the WETH9 contract
    const weth9Addr = await swapRouter02.WETH9();

    console.log("Selling tokens...");
    console.log("Chain ID:", chainId);
    console.log("Token:", deployments.Tickets404);
    console.log("WETH9:", weth9Addr);
    console.log("Swap Router:", SWAP_ROUTER02);
    console.log("Seller Address:", seller.address);

    // check if we need to approve
    const allowance = await token.allowance(seller.address, swapRouter02.address);
    const balance = await token.balanceOf(seller.address);
    if (allowance.lt(balance)) {
        console.log("Approving tokens to swap router...");
        await (await token.connect(seller).approve(swapRouter02.address, ethers.constants.MaxUint256)).wait(3);
    }

    // buy tokens
    console.log("AmountIn :", ethers.utils.formatEther(balance), "TICKETS");
    const tx = await swapRouter02.exactInputSingle({
        tokenIn: token.address,
        tokenOut: weth9Addr,
        fee: fee,
        recipient: seller.address,
        amountIn: balance,
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0
    });
    console.log("Tokens sold:", tx.hash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});