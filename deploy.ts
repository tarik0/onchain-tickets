import { ethers } from "hardhat";
import {Tickets404} from "../typechain-types";
import fs from "fs";

///
/// Deployment
///

async function main() {
    let totalGasSpent = 0;
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // fetch chain id
    const chainId = (await ethers.provider.getNetwork()).chainId;
    const IS_TESTNET = chainId == 11155111 || chainId == 84532; // sepolia or base sepolia
    console.log("Chain ID:", chainId);

    // deploy style contract
    console.log("Deploying RendererStyle...")
    const _style = await ethers.getContractFactory("RendererStyle");
    const style = await _style.deploy();
    await style.deployed();
    console.log("RendererStyle deployed to:", style.address)

    let deployTx = await style.deployTransaction.wait(3);
    totalGasSpent += deployTx.gasUsed.toNumber();

    // deploy renderer contract
    console.log("Deploying MetadataRenderer...")
    const _renderer = await ethers.getContractFactory("MetadataRenderer");
    const renderer = await _renderer.deploy(style.address);
    await renderer.deployed();
    console.log("MetadataRenderer deployed to:", renderer.address)

    deployTx = await renderer.deployTransaction.wait(3);
    totalGasSpent += deployTx.gasUsed.toNumber();

    // deploy mirror contract
    console.log("Deploying DN404Mirror...")
    const _mirror = await ethers.getContractFactory("DN404Mirror");
    const mirror = await _mirror.deploy(deployer.address);
    await mirror.deployed();
    console.log("DN404Mirror deployed to:", mirror.address)

    deployTx = await mirror.deployTransaction.wait(3);
    totalGasSpent += deployTx.gasUsed.toNumber();

    // deploy token contract
    console.log("Deploying Tickets404...")
    const _token = await ethers.getContractFactory(IS_TESTNET ? "MockedTickets404" : "Tickets404");
    const token = await _token.deploy();
    await token.deployed();
    console.log("Tickets404 deployed to:", token.address)

    deployTx = await token.deployTransaction.wait(3);
    totalGasSpent += deployTx.gasUsed.toNumber();

    // create new default referrer wallet
    const defaultReferrer = ethers.Wallet.createRandom();

    // deploy referral contract
    console.log("Deploying Referral...")
    console.log("Default Referrer:", defaultReferrer.address)
    const _referral = await ethers.getContractFactory("Referrals");
    const referral = await _referral.deploy(token.address, defaultReferrer.address);
    await referral.deployed();
    console.log("Referral deployed to:", referral.address)

    deployTx = await referral.deployTransaction.wait(3);
    totalGasSpent += deployTx.gasUsed.toNumber();

    // save the contract addresses to deployments/chainId.json
    const deployments = {
        RendererStyle: style.address,
        MetadataRenderer: renderer.address,
        Referral: referral.address,
        Tickets404: token.address,
        DN404Mirror: mirror.address,
        DefaultReferrer: defaultReferrer.address,
        DefaultReferrerKey: defaultReferrer.privateKey,
        // important flags
        IS_TESTNET: IS_TESTNET,
        TOTAL_GAS_SPENT: totalGasSpent,
        IS_INITIALIZED: false,
        IS_TRADE_ENABLED: false,
        SPONSOR_WALLET: ""
    };

    console.log("Total Gas Spent:", totalGasSpent, "wei");

    // overwrite the file if it exists
    await fs
        .promises
        .writeFile(`deployments/${chainId}.json`, JSON.stringify(deployments, null, 4), { flag: "w" });

    console.log("Deployments saved to deployments/" + chainId + ".json");
    console.log("Token is deployed! You can initialize it now.")
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
