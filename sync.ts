import { ethers } from "hardhat";
import fs from "fs";

///
/// Sync the lottery.
///

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

    console.log("Syncing lottery...");
    console.log("Chain ID:", chainId);
    console.log("Token:", deployments.Tickets404);

    const tx = await token.syncLottery();
    console.log("Lottery synced!", tx.hash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});