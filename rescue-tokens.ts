import { ethers } from "hardhat";
import fs from "fs";

///
/// Rescue Tokens
///

async function main() {
    // read deployed contracts from deployments/chainId.json
    const chainId = (await ethers.provider.getNetwork()).chainId;
    const deployments = JSON.parse(fs.readFileSync(`deployments/${chainId}.json`).toString());
    if (!deployments.Tickets404) {
        console.error(`Tickets404 contract not found in deployments/${chainId}.json`);
        process.exit(1);
    }
    console.log("Token:", deployments.Tickets404);

    // rescue tokens
    console.log("Rescuing tokens...")
    const token = await ethers.getContractAt("Tickets404", deployments.Tickets404);
    const tx = await token.rescueToken()
    console.log("Rescue tokens tx:", tx.hash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});