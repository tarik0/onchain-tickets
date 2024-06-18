import { ethers } from "hardhat";
import fs from "fs";

///
/// Increase the prize pool.
///

const PRIZE_AMOUNT = ethers.utils.parseEther("0.001");

async function main() {
    // read deployed contracts from deployments/chainId.json
    const chainId = (await ethers.provider.getNetwork()).chainId;
    const deployments = JSON.parse(fs.readFileSync(`deployments/${chainId}.json`).toString());
    if (!deployments.Tickets404) {
        console.error(`Tickets404 contract not found in deployments/${chainId}.json`);
        process.exit(1);
    }

    // get the contract
    const token = await ethers.getContractAt("ITickets404", deployments.Tickets404);

    console.log("Increasing prize...");
    console.log("Chain ID:", chainId);
    console.log("Token:", deployments.Tickets404);
    console.log("Prize Amount:", ethers.utils.formatEther(PRIZE_AMOUNT), "ETH");

    // increase the prize
    const [deployer] = await ethers.getSigners();
    let tx = await deployer.sendTransaction({
        to: deployments.Tickets404,
        value: PRIZE_AMOUNT,
    }).then(tx => tx.wait(3));
    console.log("Prize increased!", tx.transactionHash);

    // sync the lottery
    console.log("Syncing lottery...");
    tx = await token.syncLottery().then(tx => tx.wait(3));
    console.log("Lottery synced!", tx.transactionHash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});