import {ethers, network} from "hardhat";
import {expect} from "chai";
import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {buyTokens, buyTokensWithOutput, findTokenIds, sellTokens, tradeFixture} from "./util/uniswap";
import {BigNumber} from "ethers";
import {Referrals} from "../typechain-types";
import {normalizeSeed, seedForProbability} from "./util/seed";

describe("Probabilities", function () {
    ///
    /// Should allow users to generate prize pool & sync new probabilities.
    ///

    it("should allow users to generate prize pool & sync new probabilities", async function () {
        const {token} = await loadFixture(tradeFixture);
        const [,signerB] = await ethers.getSigners();

        const beforeProb = await token.ticketProbability(6);

        // transfer tokens from owner to contract
        await token.transfer(token.address, await token.balanceOf(await token.owner()));

        // sync probabilities
        await expect(
            token.connect(signerB).syncLottery()
        ).to.emit(token, "PrizePoolIncreased");

        const afterProb = await token.ticketProbability(2);
        expect(afterProb).to.not.eq(beforeProb, "probability not changed");
    });

    ///
    /// Should have less fulfillment gas cost than 5M for max ticket refresh
    ///

    it("should have less fulfillment gas cost than 2M for max ticket refresh", async function () {
        const {token, uniswap, airnodeRrp} = await loadFixture(tradeFixture);
        const [, signerB] = await ethers.getSigners();

        // get max ticket refresh
        const maxTicketRefresh = await token.maxTicketRefresh();

        // set fee to zero
        await token.setPrizePoolTax({Numerator: 0, Denominator: 1});

        // buy tokens that's less than max. refresh
        const nextReqId = await airnodeRrp.nextRequestId();
        const buyTx = await buyTokensWithOutput(uniswap.router02.connect(signerB), token.address, ethers.utils.parseEther(maxTicketRefresh.toString()));
        await buyTx.wait();

        // fetch logs
        const logs = await token.queryFilter(
            token.filters.SeedRequestedForRange()
        );
        expect(logs.length).to.eq(1);

        // fulfill requests
        const fulfillTx = await airnodeRrp.mockFulfillWithRange(
            nextReqId
        );
        const receipt = await fulfillTx.wait();

        // fetch gas used
        expect(receipt.gasUsed.toNumber()).to.lt(2_000_000, "gas cost exceeded");
    });

    ///
    /// Should increase total minted probability after seed fulfillment.
    ///

    it("should increase total minted probability after seed fulfillment", async function () {
        const {token, uniswap} = await loadFixture(tradeFixture);
        const [, signerB] = await ethers.getSigners();

        // make sure the total minted rarity is zero
        expect(await token.totalTicketProbabilities()).to.eq(0);

        // buy tokens that's less than max. wallet
        const buyTx = buyTokens(uniswap.router02.connect(signerB), token.address, ethers.utils.parseEther("0.01"));
        await expect(buyTx).to.emit(token, "SeedRequestedForRange");

        // find token ids
        const tokenIds = await findTokenIds((await buyTx).hash);

        // fetch emerald probability
        const ticketProbability = await token.ticketProbability(6); // Emerald

        // override seeds
        const tokenId = tokenIds[0];
        const rawSeed = seedForProbability(BigNumber.from(tokenId), ticketProbability);
        await token.setTicketSeed(rawSeed, tokenId, false);

        // expect seed to be set
        const [seed,] = await token.getTicketSeed(tokenId);
        expect(normalizeSeed(rawSeed, tokenId)).to.eq(seed, "seed not set correctly");

        // expect tokens to be emerald
        const ticket = await token.getTicket(tokenId);
        expect(ticket.ticketType).to.eq(6, "seed not set correctly");

        // total minted rarity should be updated
        expect(await token.totalTicketProbabilities()).to.not.eq(0);
    });

    ///
    /// Should decrease total minted rarity after selling tokens.
    ///

    it("should decrease total minted rarity after selling tokens", async function () {
        const {token, uniswap} = await loadFixture(tradeFixture);
        const [, signerB] = await ethers.getSigners();

        // buy tokens
        const buyTx = await buyTokens(
            uniswap.router02.connect(signerB), token.address, ethers.utils.parseEther("0.01")
        );

        // fetch ticket probability
        const ticketProbability = await token.ticketProbability(6); // Emerald

        // fetch token ids & override seeds
        const tokenIds = await findTokenIds(buyTx.hash);
        await Promise.all(
            tokenIds.map((tokenId) => {
                const rawSeed = seedForProbability(BigNumber.from(tokenId), ticketProbability);
                return token.setTicketSeed(rawSeed, tokenId, false);
            })
        );

        // wait 1 block
        await ethers.provider.send("evm_mine", []);

        // expect seed to be set
        const [seed,] = await token.getTicketSeed(tokenIds[0]);
        expect(
            normalizeSeed(seedForProbability(BigNumber.from(tokenIds[0]), ticketProbability), tokenIds[0])
        ).to.eq(seed, "seed not set correctly");

        // wait 1 block
        await ethers.provider.send("evm_mine", []);

        // approve tokens
        const tokenBalance = await token.balanceOf(signerB.address);
        await token.connect(signerB).approve(uniswap.router02.address, tokenBalance);

        // wait 1 block
        await ethers.provider.send("evm_mine", []);

        // sell tokens
        await sellTokens(uniswap.router02.connect(signerB), token.address, tokenBalance)

        // wait 1 block
        await ethers.provider.send("evm_mine", []);

        // expect balance to be zero
        expect(await token.balanceOf(signerB.address)).to.eq(0);

        // total minted rarity should be zero
        expect(await token.totalTicketProbabilities()).to.eq(0);
    });

    ///
    /// Should decrease the probability weight when price increases.
    ///

    it("should decrease the probability weight of tickets when price increases", async function () {
        const {token, uniswap} = await loadFixture(tradeFixture);
        const [,signerA] = await ethers.getSigners();

        // set max wallet
        await token.setMaxWallet(ethers.constants.MaxUint256);
        await token.setMaxTicketRefresh(ethers.constants.MaxUint256);

        // fetch ticket price
        const [firstPrice,] = await token.ticketPrices();

        const ticketEnum = 2; // Bronze
        const beforeProb = await token.ticketProbability(ticketEnum);

        // buy tokens and increase the price
        await buyTokens(uniswap.router02.connect(signerA), token.address, ethers.utils.parseEther("0.1"));

        // fetch ticket price
        const [secondPrice, initial] = await token.ticketPrices();
        expect(secondPrice).to.gt(firstPrice, "price not increased");

        // estimate the new probability
        const estimated = beforeProb.sub(secondPrice.div(initial).mul(beforeProb).div(1000));

        // fetch ticket probability
        const afterProb = await token.ticketProbability(ticketEnum);
        expect(afterProb).to.eq(estimated, "probability not increased");
    });

    ///
    /// Should increase the probability weight when price decreases.
    ///

    it("should increase the probability weight of tickets when price decreases", async function () {
        const {token, uniswap} = await loadFixture(tradeFixture);
        const [,signerA] = await ethers.getSigners();

        // set max wallet
        await token.setMaxWallet(ethers.constants.MaxUint256);
        await token.setMaxTicketRefresh(ethers.constants.MaxUint256);

        // wait 1 block
        await ethers.provider.send("evm_mine", []);
        await network.provider.send('hardhat_setNextBlockBaseFeePerGas', ['0x0'])

        // buy tokens to increase the price
        await buyTokens(uniswap.router02.connect(signerA), token.address, ethers.utils.parseEther("0.1"));

        // wait 1 block
        await ethers.provider.send("evm_mine", []);
        await network.provider.send('hardhat_setNextBlockBaseFeePerGas', ['0x0'])

        // get owner balance & approve
        const ownerBalance = await token.balanceOf(signerA.address);
        await token.connect(signerA).approve(uniswap.router02.address, ownerBalance);

        // wait 1 block
        await ethers.provider.send("evm_mine", []);
        await network.provider.send('hardhat_setNextBlockBaseFeePerGas', ['0x0'])

        const ticketEnum = 2; // Bronze
        const beforeProb = await token.ticketProbability(ticketEnum);

        // sell tokens and decrease the price
        await sellTokens(uniswap.router02.connect(signerA), token.address, ownerBalance);

        // wait 1 block
        await ethers.provider.send("evm_mine", []);
        await network.provider.send('hardhat_setNextBlockBaseFeePerGas', ['0x0'])

        // estimate the new probability
        const estimated = beforeProb.add(BigNumber.from(2).div(1000));

        // fetch ticket probability
        const afterProb = await token.ticketProbability(ticketEnum);
        expect(afterProb).to.eq(estimated, "probability not decreased");
    });

    ///
    /// Should add %10 referral bonus to the account that referred
    ///

    it("should add %10 referral bonus to the account that referred", async function () {
        const {token, uniswap} = await loadFixture(tradeFixture);
        const [,signerA, signerB] = await ethers.getSigners();

        // get referral contract
        const referrals : Referrals = await token.helperContracts()
            .then((addresses: any) => {
                return ethers.getContractAt("Referrals", addresses.referrals);
            });

        // set fees to zero
        await token.setPrizePoolTax({Numerator: 0, Denominator: 1});

        // use signerA as referrer
        await referrals
            .connect(signerB)
            .setReferral(signerA.address);

        // buy token with signerA
        const tx = await buyTokensWithOutput(
            uniswap.router02.connect(signerA), token.address, ethers.utils.parseEther("3")
        );

        // fetch token ids
        const tokenIds = await findTokenIds(tx.hash);
        expect(tokenIds.length).to.gte(1);
        const tokenIdA = tokenIds[0];

        // set dummy probabilities
        await token.setProbabilities({
            Bronze: 1_000_000,
            Silver: 2**32-4,
            Gold: 2**32-3,
            Diamond: 2**32-2,
            Emerald: 2**32-1,
        })

        // emerald probability
        const bronze = await token.ticketProbability(2);

        // set seed for tokenId
        const newSeed = seedForProbability(tokenIdA, bronze.mul(90).div(100));
        await token.setTicketSeed(
            newSeed, tokenIdA, true
        )

        // expect ticket to be non-emerald
        const ticketA = await token.getTicket(tokenIdA);
        expect(ticketA.ticketType).to.not.eq(6, "ticket is bronze");

        // transfer token to signerB
        await token.connect(signerA).transferNFT(signerB.address, tokenIdA);

        // expect ticket to be bronze
        const ticketB = await token.getTicket(tokenIdA);
        expect(ticketB.ticketType).to.eq(2, "ticket not bronze");
    });
});