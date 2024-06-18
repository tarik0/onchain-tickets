import { ethers } from "hardhat";
import {Tickets404} from "../typechain-types";
import fs from "fs";

///
/// Enable transfer & start trading
///

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

    console.log("Starting trade...");
    console.log("Chain ID:", chainId);
    console.log("Token:", deployments.Tickets404);
    const token = await ethers.getContractAt("Tickets404", deployments.Tickets404) as Tickets404;

    // start trading
    const tx = await token.initializeTransfer();
    console.log("Trade started:", tx.hash);

    deployments.IS_TRADE_ENABLED = true;
    await fs.
        promises.
        writeFile(`deployments/${chainId}.json`, JSON.stringify(deployments, null, 2));

    console.log("You can now trade the tokens on Uniswap.");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});