import { ethers } from "hardhat";
import fs from "fs";
import {Tickets404} from "../../typechain-types";

///
/// Exclude from tax
///

const ADDR = "0x231278eDd38B00B07fBd52120CEf685B9BaEBCC1"

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

    console.log("Excluding from tax...");
    console.log("Chain ID:", chainId);
    console.log("Token:", deployments.Tickets404);
    const token = await ethers.getContractAt("Tickets404", deployments.Tickets404) as Tickets404;

    // whitelist address
    const tx = await token.setExcludeTax(ADDR, true);
    console.log("Excluded from tax:", tx.hash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});