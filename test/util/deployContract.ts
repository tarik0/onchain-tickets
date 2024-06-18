import {Contract, ContractFactory, Signer} from "ethers";
import {ethers, network} from "hardhat";
import {linkLibraries} from "./linkLibraries";
import {IMockedTickets404__factory, MockedTickets404} from "../../typechain-types";

type ContractJson = { abi: any; bytecode: string };
export const artifacts: { [name: string]: ContractJson } = {
    UniswapV3Factory: require("@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json"),
    SwapRouter: require("@uniswap/v3-periphery/artifacts/contracts/SwapRouter.sol/SwapRouter.json"),
    NFTDescriptor: require("@uniswap/v3-periphery/artifacts/contracts/libraries/NFTDescriptor.sol/NFTDescriptor.json"),
    NonfungibleTokenPositionDescriptor: require("@uniswap/v3-periphery/artifacts/contracts/NonfungibleTokenPositionDescriptor.sol/NonfungibleTokenPositionDescriptor.json"),
    NonfungiblePositionManager: require("@uniswap/v3-periphery/artifacts/contracts/NonfungiblePositionManager.sol/NonfungiblePositionManager.json"),
    UniswapV3Pool: require("@uniswap/v3-core/artifacts/contracts/UniswapV3Pool.sol/UniswapV3Pool.json"),
    WETH9: require("./artifacts/WETH9.json"),
    SwapRouter02: require("./artifacts/SwapRouter02.json"),
};

export async function deployContract<T>(
    abi: any,
    bytecode: string,
    deployParams: Array<any>,
    actor: Signer
) {
    const factory = new ContractFactory(abi, bytecode, actor);
    const contract = await factory.deploy(...deployParams)
    await contract.deployed();
    await ethers.provider.send("evm_mine", []);
    await network.provider.send('hardhat_setNextBlockBaseFeePerGas', ['0x0'])
    return contract as T;
}

export async function deployUniswap() {
    const [deployer] = await ethers.getSigners();

    const weth9 = await deployContract<Contract>(
        artifacts.WETH9.abi,
        artifacts.WETH9.bytecode,
        [],
        deployer
    );
    const factory = await deployContract<Contract>(
        artifacts.UniswapV3Factory.abi,
        artifacts.UniswapV3Factory.bytecode,
        [],
        deployer
    );
    const router = await deployContract<Contract>(
        artifacts.SwapRouter.abi,
        artifacts.SwapRouter.bytecode,
        [factory.address, weth9.address],
        deployer
    );
    const nftDescriptor = await deployContract<Contract>(
        artifacts.NFTDescriptor.abi,
        artifacts.NFTDescriptor.bytecode,
        [],
        deployer
    );

    const linkedBytecode = linkLibraries(
        {
            bytecode: artifacts.NonfungibleTokenPositionDescriptor.bytecode,
            linkReferences: {
                "NFTDescriptor.sol": {
                    NFTDescriptor: [
                        {
                            length: 20,
                            start: 1261,
                        },
                    ],
                },
            },
        },
        {
            NFTDescriptor: nftDescriptor.address,
        }
    );

    const positionDescriptor = await deployContract<Contract>(
        artifacts.NonfungibleTokenPositionDescriptor.abi,
        linkedBytecode,
        [weth9.address],
        deployer
    );

    const positionManager = await deployContract<Contract>(
        artifacts.NonfungiblePositionManager.abi,
        artifacts.NonfungiblePositionManager.bytecode,
        [factory.address, weth9.address, positionDescriptor.address],
        deployer
    );

    const router02 = await deployContract<Contract>(
        artifacts.SwapRouter02.abi,
        artifacts.SwapRouter02.bytecode,
        [
            factory.address,
            factory.address,
            positionManager.address,
            weth9.address
        ],
        deployer
    );

    return {
        weth9,
        factory,
        router,
        router02,
        nftDescriptor,
        positionDescriptor,
        positionManager,
    };
}

export async function deployMockedAirnodeRrp() {
    const _airnodeRrp = await ethers.getContractFactory("MockedAirnodeRrp");
    const airnodeRrp = await _airnodeRrp.deploy();
    await airnodeRrp.deployed();

    const airnode = "0x0000000000000000000000000000000000000003";
    const sponsor = "0x0000000000000000000000000000000000000004";
    const endpoint = "0x0000000000000000000000000000000000000000000000000000000000000123";

    return { airnodeRrp, airnode, sponsor, endpoint };
}

export async function deployRenderer() {
    // deploy style
    const _style = await ethers.getContractFactory("RendererStyle");
    const style = await _style.deploy();
    await style.deployed();

    // deploy renderer
    const _renderer = await ethers.getContractFactory("MetadataRenderer");
    const renderer = await _renderer.deploy(style.address);
    await renderer.deployed();

    return { style, renderer };
}

export async function deployToken(isMocked = false) {
    const _token = await ethers.getContractFactory(isMocked ? "MockedTickets404" : "Tickets404");
    const token = await _token.deploy();
    await token.deployed();

    return IMockedTickets404__factory.connect(token.address, token.signer);
}

export async function deployMirror() {
    const _mirror = await ethers.getContractFactory("DN404Mirror");
    const mirror = await _mirror.deploy(_mirror.signer.getAddress());
    await mirror.deployed();

    return mirror;
}

export async function deployReferrals(tokenAddr: string, defaultReferrer: string) {
    const _referrals = await ethers.getContractFactory("Referrals");
    const referrals = await _referrals.deploy(tokenAddr, defaultReferrer);
    await referrals.deployed();

    return referrals;
}