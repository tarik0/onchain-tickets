import { ethers } from "hardhat";
import fs from "fs";
import {BigNumber} from "ethers";

///
/// Uniswap Artifacts
///

type ContractJson = { abi: any; bytecode: string };
export const uniswapArtifacts: { [name: string]: ContractJson } = {
    WETH9: require("./../../test/util/artifacts/WETH9.json"),
    SwapRouter02: require("./../../test/util/artifacts/SwapRouter02.json"),
};

///
/// Buy tokens after the trade starts.
/// - buys tokens with the output amount.
/// - tries to buy tokens that's less than max ticket refresh.
///

const BUYER_WALLET = process.env.BUYER_WALLET;
const SWAP_ROUTER02 = "0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4";
const MAX_AMOUNT_IN = ethers.utils.parseEther("0.001");
const FEE = 10000;

async function main() {
    if (!BUYER_WALLET) {
        console.error("BUYER_WALLET is not set");
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
    const token = await ethers.getContractAt("ITickets404", deployments.Tickets404);
    const buyer = new ethers.Wallet(BUYER_WALLET, ethers.provider);
    const swapRouter02 = new ethers.Contract(SWAP_ROUTER02, uniswapArtifacts.SwapRouter02.abi, buyer);

    // get the WETH9 contract
    const weth9Addr = await swapRouter02.WETH9();
    const weth9 = new ethers.Contract(weth9Addr, uniswapArtifacts.WETH9.abi, buyer);
    console.log("Buying tokens...");
    console.log("Chain ID:", chainId);
    console.log("Token:", deployments.Tickets404);
    console.log("WETH9:", weth9Addr);
    console.log("Swap Router:", SWAP_ROUTER02);
    console.log("Buyer Address:", buyer.address);

    // find the max ticket
    const maxTicketRefresh = await token.maxTicketRefresh();
    const amountOut = BigNumber.from(maxTicketRefresh).mul(ethers.constants.WeiPerEther);

    // deposit WETH
    console.log("Depositing WETH...")
    if ((await weth9.balanceOf(buyer.address)).lt(MAX_AMOUNT_IN)) {
        await (await weth9.deposit({ value: MAX_AMOUNT_IN })).wait(3);
    }

    // approve WETH
    console.log("Approving WETH...")
    if ((await weth9.allowance(buyer.address, SWAP_ROUTER02)).lt(MAX_AMOUNT_IN)) {
        await (await weth9.approve(SWAP_ROUTER02, ethers.constants.MaxUint256)).wait(3);
    }

    // buy tokens
    console.log("Amount Out:", ethers.utils.formatEther(amountOut), "TICKET");
    const tx = await swapRouter02.exactOutputSingle({
        tokenIn: weth9Addr,
        tokenOut: token.address,
        fee: FEE,
        recipient: buyer.address,
        deadline: ethers.constants.MaxUint256,
        amountOut: amountOut,
        amountInMaximum: MAX_AMOUNT_IN,
        sqrtPriceLimitX96: 0
    });
    console.log("Tokens bought:", tx.hash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});