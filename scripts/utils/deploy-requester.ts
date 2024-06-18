import { ethers } from "hardhat";
import {deriveSponsorWalletAddress} from "@api3/airnode-admin";

///
/// Deploys the mocked airnode requester
/// - for testing purposes
///

const TESTNET_SETTINGS = {
    AirnodeRRP: "0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd",
    Airnode: "0x6238772544f029ecaBfDED4300f13A3c4FE84E1D",
    Endpoint: "0x94555f83f1addda23fdaa7c74f27ce2b764ed5cc430c66f5ff1bcf39d583da36",
    XPub: "xpub6CuDdF9zdWTRuGybJPuZUGnU4suZowMmgu15bjFZT2o6PUtk4Lo78KGJUGBobz3pPKRaN9sLxzj21CMe6StP3zUsd8tWEJPgZBesYBMY7Wo",
    InitialSponsorBalance: ethers.utils.parseEther("0.01")
}

const MAINNET_SETTINGS = {
    AirnodeRRP: "0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd",
    Airnode: "0x224e030f03Cd3440D88BD78C9BF5Ed36458A1A25",
    Endpoint: "0xffd1bbe880e7b2c662f6c8511b15ff22d12a4a35d5c8c17202893a5f10e25284",
    XPub: "xpub6CyZcaXvbnbqGfqqZWvWNUbGvdd5PAJRrBeAhy9rz1bbnFmpVLg2wPj1h6TyndFrWLUG3kHWBYpwacgCTGWAHFTbUrXEg6LdLxoEBny2YDz",
    InitialSponsorBalance: ethers.utils.parseEther("0.0005")
}

async function main() {
    const [deployer] = await ethers.getSigners();
    const chainId = await ethers.provider.getNetwork().then((network) => network.chainId);
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Chain ID:", chainId);
    console.log("Deploying MockedRequester...");

    // deploy requester
    const _requester = await ethers.getContractFactory("MockedRequester");
    const requester = await _requester.deploy();
    await requester.deployed();
    console.log("MockedRequester deployed to:", requester.address);

    // find the sponsor wallet
    const settings = (chainId == 11155111 || chainId == 84532) ? TESTNET_SETTINGS : MAINNET_SETTINGS;
    const sponsorWallet = deriveSponsorWalletAddress(settings.XPub, settings.Airnode, requester.address);
    console.log("Sponsor Wallet:", sponsorWallet);

    // initialize the requester
    console.log("Initializing requester...");
    await requester.setSettings(settings.AirnodeRRP, settings.Airnode, sponsorWallet, settings.Endpoint)
        .then((tx) => tx.wait(3));

    // transfer initial sponsor balance
    await deployer.sendTransaction({
        to: sponsorWallet,
        value: settings.InitialSponsorBalance,
    }).then((tx) => tx.wait(3));
    console.log("Initial Sponsor Balance:", ethers.utils.formatEther(settings.InitialSponsorBalance), "ETH");
    console.log("Initial sponsor balance transferred to:", sponsorWallet);

    // request data
    console.log("Requesting seed for 500 tokens...")
    const receipt = await requester.requestUint256(500)
        .then((tx) => tx.wait(3));
    console.log("Request receipt:", receipt.transactionHash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});