import {BigNumber, BigNumberish, Contract} from "ethers";
import {ethers} from "hardhat";
import {
    deployMirror,
    deployMockedAirnodeRrp,
    deployReferrals,
    deployRenderer,
    deployToken,
    deployUniswap
} from "./deployContract";
import {expect} from "chai";

///
/// Default Pool Settings
///

export const etherLiquidity = ethers.utils.parseEther("4.5");
export const tokenLiquidity = ethers.utils.parseEther("40000");
export const fee = 10000; // 0.1%

///
/// Uniswap Helper Functions
///

export function sqrtUsingNewton(x: BigNumber): BigNumber {
    let z = x;
    let y = x.div(2).add(1);

    while (y.lt(z)) {
        z = y;
        y = x.div(z).add(z).div(2);
    }
    return z;
}

export function calculateSqrtPriceX96(amount0: BigNumber, amount1: BigNumber): BigNumber {
    const num = amount1.shl(192);
    const ratioX192 = num.div(amount0);
    return sqrtUsingNewton(ratioX192);
}

///
/// Deploys token and uniswap, and initializes the pool
///

export const tradeFixture = async () => {
    // deploy renderer, token, and uniswap
    const {renderer} = await deployRenderer();
    const mirror = await deployMirror();
    const token = await deployToken(true);
    const defaultReferrer = ethers.Wallet.createRandom().address;
    const uniswap = await deployUniswap();
    const {sponsor, airnode, airnodeRrp, endpoint} = await deployMockedAirnodeRrp();
    const referrals = await deployReferrals(token.address, defaultReferrer);

    // approve token to uniswap
    await token.approve(uniswap.positionManager.address, ethers.constants.MaxUint256);
    await uniswap.weth9.approve(uniswap.positionManager.address, ethers.constants.MaxUint256);

    // initialize token
    await token.initializeToken({
        AirnodeRrp: airnodeRrp.address,
        Airnode: airnode,
        SponsorWallet: sponsor,
        EndpointIdUint256: endpoint
    }, mirror.address, renderer.address, referrals.address);

    // initialize pool
    await token.initializePool(uniswap.router02.address, uniswap.positionManager.address, fee);

    // wrap ether
    await uniswap.weth9.deposit({value: etherLiquidity});

    // fetch pair
    const poolDetails = await token.pool()

    // sort tokens for pair
    let [token0, token1] = [uniswap.weth9.address, token.address];
    let [amount0, amount1] = [etherLiquidity, tokenLiquidity];
    if (BigNumber.from(token1).lt(BigNumber.from(token0))) {
        [token0, token1] = [token1, token0];
        [amount0, amount1] = [amount1, amount0];
    }

    // encode sqrt price
    const initialSqrtPriceX96 = calculateSqrtPriceX96(
        amount0,
        amount1
    );

    // initialize pool
    await uniswap.positionManager.createAndInitializePoolIfNecessary(
        token0,
        token1,
        fee,
        initialSqrtPriceX96
    );

    // add liquidity and send it to deployer
    const [deployer] = await ethers.getSigners();
    const tx = await uniswap.positionManager.mint({
        token0: token0,
        token1: token1,
        fee: fee,
        tickLower: "-887200",
        tickUpper: "887200",
        amount0Desired: amount0,
        amount1Desired: amount1,
        amount0Min: amount0.mul(95).div(100),
        amount1Min: amount1.mul(95).div(100),
        recipient: deployer.address,
        deadline: ethers.constants.MaxUint256,
    });

    // find token ids
    const tokenIds = await findTokenIds(tx.hash);
    expect(tokenIds.length).to.gt(0, "no tokens found");

    // enable user transfers
    await token.initializeTransfer();
    return {
        token, uniswap, referrals,
        airnodeRrp, airnode, sponsor,
        poolDetails, initialSqrtPriceX96, posId: tokenIds[0] as BigNumberish,
        defaultReferrer
    };
};

///
/// Remove liquidity from the pool
///

export const removeLiquidity = (posManager: Contract, tokenId: BigNumberish) => {
    return posManager.positions(tokenId)
        .then((pos: any) =>
            posManager.decreaseLiquidity({
                tokenId: tokenId,
                liquidity: pos.liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: ethers.constants.MaxUint256
            })
        )
        .then(() => posManager.signer.getAddress())
        .then((addr: any) =>
            posManager.collect({
                tokenId: tokenId,
                recipient: addr,
                amount0Max: BigNumber.from(2).pow(128).sub(1),
                amount1Max: BigNumber.from(2).pow(128).sub(1),
            })
        )
};

///
/// Swaps ETH for tokens
///

export const buyTokens = (router02: Contract, tokenAddr: string, amountIn: BigNumberish) => {
    return Promise.all([
        router02.WETH9(),
        router02.signer.getAddress()
    ]).then(([wethAddr, recipient]) => {
        return router02.exactInputSingle({
            tokenIn: wethAddr,
            tokenOut: tokenAddr,
            fee: fee,
            recipient: recipient,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        }, { value: amountIn });
    });
};

// this consumes all the ETH in the wallet
// for testing purposes
export const buyTokensWithOutput = (router02: Contract, tokenAddr: string, amountOut: BigNumberish) => {
    return Promise.all([
        router02.WETH9(),
        router02.signer.getAddress(),
        router02.signer.getBalance()
    ]).then(([wethAddr, recipient, maxEth]) => {
        return router02.exactOutputSingle({
            tokenIn: wethAddr,
            tokenOut: tokenAddr,
            fee: fee,
            recipient: recipient,
            amountOut: amountOut,
            amountInMaximum: maxEth,
            sqrtPriceLimitX96: 0
        }, { value: maxEth });
    });
}

///
/// Swaps tokens for ETH
///

export const sellTokens = (router02: Contract, tokenAddr: string, amountIn: BigNumberish) => {
    return Promise.all([
        router02.WETH9(),
        router02.signer.getAddress()
    ]).then(([wethAddr, recipient]) => {
        return router02.exactInputSingle({
            tokenIn: tokenAddr,
            tokenOut: wethAddr,
            fee: fee,
            recipient: recipient,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
    });
}

///
/// Fetches token IDs from a transaction
///

export const findTokenIds = async (tx: string) => {
    return ethers.provider.getTransactionReceipt(tx)
        .then((receipt) => {
            return receipt.logs
                .filter(
                    (e: any) =>
                        e.topics.length == 4 &&
                        e.topics[0] ===
                        "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
                )
                .map((e: any) => {
                    const tmp = ethers.utils.defaultAbiCoder.decode(
                        ["uint256"],
                        e.topics[3]
                    );
                    return tmp[0];
                });
        })
}