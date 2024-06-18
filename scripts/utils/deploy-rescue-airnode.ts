import { ethers } from "hardhat";
import {deriveSponsorWalletAddress} from "@api3/airnode-admin";

///
/// Deploys the rescue airnode requester
/// - for testing purposes
///

async function main() {
    const [deployer] = await ethers.getSigners();
    const chainId = await ethers.provider.getNetwork().then((network) => network.chainId);
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Chain ID:", chainId);
    console.log("Deploying RescueAirnodeRrp...");

    // deploy requester
    const _requester = await ethers.getContractFactory("RescueAirnodeRrp");
    const requester = await _requester.deploy();
    await requester.deployed();

    console.log("RescueAirnodeRrp deployed to:", requester.address);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});