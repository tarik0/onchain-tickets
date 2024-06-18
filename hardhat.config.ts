import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";
import * as dotenv from "dotenv";
import "hardhat-tracer";

dotenv.config();

const TESTNET_RPC = "https://public.stackup.sh/api/v1/node/base-sepolia";
const MAINNET_RPC = "https://base.meowrpc.com";

const config: HardhatUserConfig = {
    mocha: {
        timeout: 120_000 // 2 minutes
    },
    gasReporter: {
        token: "ETH",
        enabled: true,
        currency: "USD",
        gasPrice: 20,
    },
    solidity: {
        version: "0.8.20",
        settings: {
            optimizer: {
                enabled: true,
                runs: 20,
            },
            viaIR: true
        },
    },
    networks: {
        testnet: {
            url: TESTNET_RPC,
            accounts: [
                process.env.DEPLOYER_WALLET as string
            ].filter(Boolean),
        },
        mainnet: {
            url: MAINNET_RPC,
            accounts: [process.env.DEPLOYER_WALLET as string].filter(Boolean),
        },
        hardhat: {
            gasPrice: 0,
            initialBaseFeePerGas: 0,
            chainId: 11155111,
            blockGasLimit: 60_000_000,
            allowUnlimitedContractSize: true,
        },
    },
    etherscan: {
        apiKey: {
            base: process.env.BASESCAN_API_KEY as string,
        },
        customChains: [
            {
                network: "base",
                chainId: 8453,
                urls: {
                    apiURL: "https://api.basescan.org/api",
                    browserURL: "https://basescan.org/",
                }
            }
        ]
    },
};

export default config;
