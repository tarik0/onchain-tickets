import { ethers } from "hardhat";
import fs from "fs";
import {BigNumber} from "ethers";

const TOKEN_ID_START = 15_000;
const TOKEN_ID_STOP = 18_000;

async function main() {
    // read deployed contracts from deployments/chainId.json
    const chainId = (await ethers.provider.getNetwork()).chainId;
    const deployments = JSON.parse(fs.readFileSync(`deployments/${chainId}.json`).toString());
    if (!deployments.Tickets404) {
        console.error(`Tickets404 contract not found in deployments/${chainId}.json`);
        process.exit(1);
    }

    // get the contract
    const token = await ethers.getContractAt("IMockedTickets404", deployments.Tickets404);

    console.log("Increasing prize...");
    console.log("Chain ID:", chainId);
    console.log("Token:", deployments.Tickets404);
    console.log("Token IDs:", TOKEN_ID_START, "to", TOKEN_ID_STOP);

    // iterate over tokenIDS
    for (let i = TOKEN_ID_START; i < TOKEN_ID_STOP; i++) {
        const tokenId = BigNumber.from(i.toString());
        const ticket = await token.getTicket(tokenId);

        if (ticket.ticketType <= 1) continue;

        console.log("")
        console.log("Token ID:", tokenId.toString());
        console.log("Owner:", ticket.owner.toString());
        console.log("Type:", ticket.ticketType.toString());
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});