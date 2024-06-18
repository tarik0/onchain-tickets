import { ethers } from "hardhat";
import {Tickets404} from "../typechain-types";
import fs from "fs";
import {QRND} from "../typechain-types/contracts/Tickets404";
import {deriveSponsorWalletAddress} from "@api3/airnode-admin";

///
/// QRND Settings
///

const QRND_TESTNET = {
    AirnodeRRP: "0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd",
    Airnode: "0x6238772544f029ecaBfDED4300f13A3c4FE84E1D",
    Endpoint: "0x94555f83f1addda23fdaa7c74f27ce2b764ed5cc430c66f5ff1bcf39d583da36",
    XPub: "xpub6CuDdF9zdWTRuGybJPuZUGnU4suZowMmgu15bjFZT2o6PUtk4Lo78KGJUGBobz3pPKRaN9sLxzj21CMe6StP3zUsd8tWEJPgZBesYBMY7Wo",
}

const QRND_MAINNET = {
    AirnodeRRP: "0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd",
    Airnode: "0x224e030f03Cd3440D88BD78C9BF5Ed36458A1A25",
    Endpoint: "0xffd1bbe880e7b2c662f6c8511b15ff22d12a4a35d5c8c17202893a5f10e25284",
    XPub: "xpub6CyZcaXvbnbqGfqqZWvWNUbGvdd5PAJRrBeAhy9rz1bbnFmpVLg2wPj1h6TyndFrWLUG3kHWBYpwacgCTGWAHFTbUrXEg6LdLxoEBny2YDz",
}

///
/// Liquidity Settings
///

const LIQUIDITY_TESTNET = {
    PosManager: "0xd7c6e867591608D32Fe476d0DbDc95d0cf584c8F",
    SwapRouter02: "0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4",
    Fee: 10000,
}

const LIQUIDITY_MAINNET = {
    PosManager: "0x4f225937EDc33EFD6109c4ceF7b560B2D6401009",
    SwapRouter02: "0x2626664c2603336E57B271c5C0b26F421741e481",
    Fee: 10000,
}

///
/// Add Liquidity
///

async function main() {
    // read deployed contracts from deployments/chainId.json
    const chainId = (await ethers.provider.getNetwork()).chainId;
    const deployments = JSON.parse(fs.readFileSync(`deployments/${chainId}.json`).toString());
    if (!deployments.Tickets404) {
        console.error(`Tickets404 contract not found in deployments/${chainId}.json`);
        process.exit(1);
    }
    if (deployments.IS_INITIALIZED) {
        console.error(`Contract already initialized in deployments/${chainId}.json`);
        process.exit(1);
    }

    // use the correct QRND settings
    const qrndSettings : QRND.AirnodeSettingsStruct = deployments.IS_TESTNET
        ?
        {
            AirnodeRrp: QRND_TESTNET.AirnodeRRP,
            Airnode: QRND_TESTNET.Airnode,
            EndpointIdUint256: QRND_TESTNET.Endpoint,
            SponsorWallet: deriveSponsorWalletAddress(QRND_TESTNET.XPub, QRND_TESTNET.Airnode, deployments.Tickets404),
        }
        :
        {
            AirnodeRrp: QRND_MAINNET.AirnodeRRP,
            Airnode: QRND_MAINNET.Airnode,
            EndpointIdUint256: QRND_MAINNET.Endpoint,
            SponsorWallet: deriveSponsorWalletAddress(QRND_MAINNET.XPub, QRND_MAINNET.Airnode, deployments.Tickets404)
        };

    console.log("Token:", deployments.Tickets404);
    console.log("Sponsor:", qrndSettings.SponsorWallet)

    // initialize the token
    console.log("Initializing token...")
    const token = await ethers.getContractAt("Tickets404", deployments.Tickets404) as Tickets404;
    let tx = await token.initializeToken(
        qrndSettings,
        deployments.DN404Mirror,
        deployments.MetadataRenderer,
        deployments.Referral
    )
    await tx.wait(3);
    console.log("Token initialized!", tx.hash);

    const liquiditySettings = deployments.IS_TESTNET ? LIQUIDITY_TESTNET : LIQUIDITY_MAINNET;

    // initialize the pool
    console.log("Initializing pool...")
    console.log("Router:", liquiditySettings.SwapRouter02)
    console.log("PosManager:", liquiditySettings.PosManager)
    console.log("Fee:", liquiditySettings.Fee)
    tx = await token.initializePool(liquiditySettings.SwapRouter02, liquiditySettings.PosManager, liquiditySettings.Fee)
    await tx.wait(3);
    console.log("Pool initialized!", tx.hash);

    // update the deployments file
    deployments.IS_INITIALIZED = true;
    deployments.SPONSOR_WALLET = qrndSettings.SponsorWallet;
    await fs
        .promises
        .writeFile(`deployments/${chainId}.json`, JSON.stringify(deployments, null, 4), { flag: "w" });

    console.log("Token & pool initialized! You can add liquidity now.")
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});