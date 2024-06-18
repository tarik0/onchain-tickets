import { ethers } from "hardhat";
import fs from "fs";
import {BigNumber} from "ethers";
import {calculateSqrtPriceX96} from "../../test/util/uniswap";

///
/// Uniswap Artifacts
///

type ContractJson = { abi: any; bytecode: string };
export const uniswapArtifacts: { [name: string]: ContractJson } = {
    UniswapV3Factory: require("@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json"),
    NonfungiblePositionManager: require("@uniswap/v3-periphery/artifacts/contracts/NonfungiblePositionManager.sol/NonfungiblePositionManager.json"),
    UniswapV3Pool: require("@uniswap/v3-core/artifacts/contracts/UniswapV3Pool.sol/UniswapV3Pool.json"),
    WETH9: require("./../../test/util/artifacts/WETH9.json"),
    SwapRouter02: require("./../../test/util/artifacts/SwapRouter02.json"),
};

///
/// Add liquidity after the initialization.
/// - adds liquidity to the pool.
/// - initializes the V3 pool with sqrt price.
///

const POS_MANAGER = "0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2";
const SWAP_ROUTER02 = "0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4";
const FEE = 10000;

const ETHER_AMOUNT = ethers.utils.parseEther("0.06");
const TOKEN_AMOUNT = ethers.utils.parseEther("70000");


async function main() {
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
    const token = await ethers.getContractAt("ITickets404", deployments.Tickets404);

    // get the uniswap contracts.
    const [deployer] = await ethers.getSigners();
    const posManger = new ethers.Contract(POS_MANAGER, uniswapArtifacts.NonfungiblePositionManager.abi, deployer);
    const swapRouter02 = new ethers.Contract(SWAP_ROUTER02, uniswapArtifacts.SwapRouter02.abi, deployer);

    // get the WETH9 contract
    const weth9Addr = await swapRouter02.WETH9();
    const weth9 = new ethers.Contract(weth9Addr, uniswapArtifacts.WETH9.abi, deployer);

    console.log("Adding liquidity...");
    console.log("Chain ID:", chainId);
    console.log("Token:", deployments.Tickets404);
    console.log("WETH9:", weth9Addr);
    console.log("POS Manager:", POS_MANAGER);
    console.log("Swap Router:", SWAP_ROUTER02);
    console.log("Ether Amount:", ethers.utils.formatEther(ETHER_AMOUNT));
    console.log("Token Amount:", ethers.utils.formatEther(TOKEN_AMOUNT));

    // approve the token to the POS Manager.
    console.log("Approving token to POS Manager...");
    if ((await token.allowance(deployer.address, POS_MANAGER)).lt(TOKEN_AMOUNT)) {
        await (await token.approve(POS_MANAGER, ethers.constants.MaxUint256)).wait(3);
    }
    if ((await weth9.allowance(deployer.address, POS_MANAGER)).lt(ETHER_AMOUNT)) {
        await (await weth9.approve(POS_MANAGER, ethers.constants.MaxUint256)).wait(3);
    }
    console.log("Approved.");

    // wrap the ether.
    console.log("Wrapping ether...");
    if ((await weth9.balanceOf(deployer.address)).lt(ETHER_AMOUNT)) {
        await (await weth9.deposit({value: ETHER_AMOUNT})).wait(3);
    }
    console.log("Wrapped.");

    // fetch pair
    const poolDetails = await token.pool()

    // sort tokens for pair
    let [token0, token1] = [weth9.address, token.address];
    let [amount0, amount1] = [ETHER_AMOUNT, TOKEN_AMOUNT];
    if (BigNumber.from(token1).lt(BigNumber.from(token0))) {
        [token0, token1] = [token1, token0];
        [amount0, amount1] = [amount1, amount0];
    }

    // encode sqrt price
    const initialSqrtPriceX96 = calculateSqrtPriceX96(
        amount0,
        amount1
    );

    // initialize pool
    console.log("Initializing V3 pool...")
    console.log("Pool:", poolDetails.Pool)
    console.log("Sqrt Price:", initialSqrtPriceX96.toString());
    console.log("Fee:", FEE);
    await (await posManger.createAndInitializePoolIfNecessary(
        token0,
        token1,
        FEE,
        initialSqrtPriceX96
    )).wait(3);

    // add liquidity and send it to deployer
    console.log("Adding liquidity...")
    const receipt = await (await posManger.mint({
        token0: token0,
        token1: token1,
        fee: FEE,
        tickLower: "-887200",
        tickUpper: "887200",
        amount0Desired: amount0,
        amount1Desired: amount1,
        amount0Min: amount0.mul(95).div(100),
        amount1Min: amount1.mul(95).div(100),
        recipient: deployer.address,
        deadline: ethers.constants.MaxUint256,
    })).wait();
    console.log("Liquidity added.");
    console.log("Transaction hash:", receipt.transactionHash);
    console.log("Liquidity added! You can start trading now.");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});