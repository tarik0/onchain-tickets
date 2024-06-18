import {ethers} from "hardhat";
import {expect} from "chai";
import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {IUniswapV3Pool__factory} from "../typechain-types";
import {
    buyTokens,
    buyTokensWithOutput,
    calculateSqrtPriceX96,
    etherLiquidity, removeLiquidity,
    sellTokens,
    tokenLiquidity,
    tradeFixture
} from "./util/uniswap";
import {BigNumber} from "ethers";

describe("Trade", function () {
    ///
    /// Should be able to add liquidity via Uniswap V3
    ///

    it("should be able to add liquidity with correct sqrtPriceX96", async function () {
        const {poolDetails, uniswap, token} = await tradeFixture();
        const pool = await IUniswapV3Pool__factory.connect(poolDetails.Pool, ethers.provider);
        const slot0 = await pool.slot0();

        // sort tokens for pair
        let [token0, token1] = [uniswap.weth9.address, token.address];
        let [amount0, amount1] = [etherLiquidity, tokenLiquidity];
        if (BigNumber.from(token1).lt(BigNumber.from(token0))) {
            [amount0, amount1] = [amount1, amount0];
        }

        // encode sqrt price
        const initialSqrtPriceX96 = calculateSqrtPriceX96(
            amount0,
            amount1
        );

        expect(slot0.sqrtPriceX96).to.eq(initialSqrtPriceX96);
    });

    ///
    /// Should be able to remove liquidity via Uniswap V3
    ///

    it("should be able to remove liquidity", async function () {
        const {uniswap, token, poolDetails, posId} = await tradeFixture();

        const beforeBal = await token.balanceOf(poolDetails.Pool);
        const beforeBal2 = await token.balanceOf(await token.owner());

        await expect(removeLiquidity(uniswap.positionManager, posId)).to.not.reverted;

        const afterBal = await token.balanceOf(poolDetails.Pool);
        const afterBal2 = await token.balanceOf(await token.owner());

        expect(afterBal).to.lt(beforeBal, "no tokens transferred to owner");
        expect(afterBal2).to.gt(beforeBal2, "no tokens transferred to owner");
    });

    ///
    /// Should have the correct probability settings
    ///

    it("should have the correct probability settings", async function () {
        const {token} = await loadFixture(tradeFixture);

        for (let i = 2; i < 7; i++) {
            expect(await token.ticketProbability(i)).to.not.eq(0);
        }
    });

    ///
    /// Should have the correct price data for the token
    ///

    it("should have the correct price for the token", async function () {
        const {token} = await tradeFixture();

        const [, initial] = await token.ticketPrices()
        const token0Price = ethers.utils.formatEther(initial);
        expect(token0Price.slice(0, 8)).to.eq("0.000112");  // ether per ticket
    });

    ///
    /// Should be able to hold tokens that's less than max. wallet
    ///

    it("should be able to hold tokens that's less than max. wallet", async function () {
        const {token, uniswap} = await loadFixture(tradeFixture);
        const [, signerB] = await ethers.getSigners();

        // fetch max wallet limit
        const maxWallet = await token.maxWallet();
        expect(maxWallet).to.gt(ethers.constants.Zero);

        // set max refreshment limit to max.
        await token.setMaxTicketRefresh(ethers.constants.MaxUint256);

        // buy tokens that's less than max. wallet
        await expect(
            buyTokensWithOutput(uniswap.router02.connect(signerB), token.address, maxWallet.sub(ethers.constants.WeiPerEther))
        ).to.not.reverted;

        // check if the balance is correct
        expect(
            await token.balanceOf(signerB.address)
        ).to.gt(ethers.constants.Zero, "swap failed");

        // buy tokens that's more than max. wallet
        await expect(
            buyTokensWithOutput(uniswap.router02.connect(signerB), token.address, maxWallet.add(ethers.constants.WeiPerEther))
        ).to.revertedWith("TF");
    });

    ///
    /// Should be able to sell tokens
    ///

    it("should be able to sell tokens", async function () {
        const {token, uniswap} = await loadFixture(tradeFixture);
        const [, signerB] = await ethers.getSigners();

        // buy tokens that's less than max. wallet
        await expect(
            buyTokensWithOutput(uniswap.router02.connect(signerB), token.address, ethers.utils.parseEther("100"))
        ).to.not.reverted;

        // check if the balance is correct
        expect(await token.balanceOf(signerB.address)).to.gt(ethers.constants.Zero, "buy swap failed");

        // approve token to sell
        const bal = await token.balanceOf(signerB.address);
        await token.connect(signerB).approve(uniswap.router02.address, bal);

        // sell tokens
        await expect(
            sellTokens(uniswap.router02.connect(signerB), token.address, bal)
        ).to.not.reverted;

        // check if the balance is correct
        expect(
            await token.balanceOf(signerB.address)
        ).to.eq(ethers.constants.Zero, "sell swap failed");
    });

    ///
    /// Should be able to mint tickets that's less than max. refreshment limit
    ///

    it("should be able to mint tickets that's less than max. refreshment limit", async function () {
        const {token, uniswap} = await loadFixture(tradeFixture);
        const [,,,, signerB] = await ethers.getSigners();

        // fetch max ticket refreshment limit
        let maxRefreshment = await token.maxTicketRefresh();
        maxRefreshment = maxRefreshment.mul(ethers.constants.WeiPerEther);

        // expect revert if mint tickets that's more than max. refreshment limit
        await expect(
            buyTokensWithOutput(uniswap.router02.connect(signerB), token.address, maxRefreshment.mul(2))
        ).to.reverted;

        // mint tickets that's less than max. refreshment limit
        await expect(
            buyTokensWithOutput(uniswap.router02.connect(signerB), token.address, maxRefreshment)
        )
            .to.emit(token, "SeedRequestedForRange");
    });

    ///
    /// Should take referral fee & prize pool fee
    ///

    it("should take referral fee & prize pool fee on buy", async function () {
        const {token, uniswap, defaultReferrer} = await loadFixture(tradeFixture);
        const [, signerB] = await ethers.getSigners();

        // fetch tax rates
        const prizePoolTax = await token.prizePoolTax();

        // calculate tax
        const amountOut = ethers.utils.parseEther("100");
        const prizePoolFee = amountOut.mul(prizePoolTax.Numerator).div(prizePoolTax.Denominator);
        const referralFee = amountOut.mul(3).div(1000);
        const amountOutAfterTax = amountOut.sub(prizePoolFee).sub(referralFee);

        // buy tokens
        await expect(
            buyTokensWithOutput(uniswap.router02.connect(signerB), token.address,amountOut)
        ).to.changeTokenBalances(
            token,
            [signerB, defaultReferrer, token.address],
            [amountOutAfterTax, referralFee, prizePoolFee]
        );
    });

    ///
    /// Should request for ticket seeds and mint tickets on buy
    ///

    it("should request for ticket seeds and mint tickets on buy", async function () {
        const {token, uniswap} = await loadFixture(tradeFixture);
        const [, signerB] = await ethers.getSigners();

        // exclude signer from tax
        await token.setExcludeTax(signerB.address, true);

        const amountOut = ethers.utils.parseEther("1");
        await expect(
            buyTokensWithOutput(uniswap.router02.connect(signerB), token.address, amountOut)
        )
            .to.changeTokenBalance(token, signerB, amountOut)
            .to.emit(token, "SeedRequestedForRange");
    })

    ///
    /// Should not request seed for already minted tickets at transfer
    ///

    it("should not request seed for already minted tickets at transfer", async function () {
        const {token, uniswap} = await loadFixture(tradeFixture);
        const [, signerB, signerC] = await ethers.getSigners();

        // buy tokens that's less than max. wallet
        await buyTokens(uniswap.router02.connect(signerB), token.address, ethers.utils.parseEther("0.01"));
        const bal = await token.balanceOf(signerB.address);

        // transfer tokens to signerC and not expect seed request
        await expect(
            token.connect(signerB).transfer(signerC.address, bal)
        ).to.not.emit(token, "SeedRequestedForRange");
    });
});