import {buyTokens, findTokenIds, tradeFixture} from "./util/uniswap";
import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {ethers} from "hardhat";
import {expect} from "chai";
import {seedForProbability} from "./util/seed";
import {BigNumber} from "ethers";

describe("Claim Rewards", function () {
    ///
    /// Should not give any rewards to invalid tickets
    ///

    it("should not give any rewards to invalid tickets", async function () {
        const {token, uniswap, airnodeRrp} = await loadFixture(tradeFixture);
        const [,signerA] = await ethers.getSigners();

        // increase the prize pool by sending eth to the contract
        const initialPoolPrize = ethers.utils.parseEther("1");
        await signerA.sendTransaction({
            to: token.address,
            value: initialPoolPrize
        });

        // expect the prize pool to be greater than zero
        const prizePool = await token.totalPrizePool();
        expect(prizePool).to.eq(initialPoolPrize, "prize pool is zero");

        // set the ticket probability to 0
        await token.setProbabilities({
            Bronze: 2**32-5,
            Silver: 2**32-4,
            Gold: 2**32-3,
            Diamond: 2**32-2,
            Emerald: 2**32-1,
        })

        // buy tokens with signerA
        const nextReq = await airnodeRrp.nextRequestId();
        const tx = await buyTokens(
            uniswap.router02.connect(signerA),
            token.address,
            ethers.utils.parseEther("0.01")
        );

        // check if the NFT balance is correct
        const balance = await token.balanceOfNFT(signerA.address);
        expect(balance).to.gt(0, "NFT balance is zero");

        // find token ids
        const tokenIds = await findTokenIds(tx.hash);
        expect(tokenIds.length).to.eq(balance, "token ids are not correct");

        // check if the rewards are correct (single)
        for (const tokenId of tokenIds) {
            // check if the ticket is "unknown"
            const ticket = await token.getTicket(tokenId)
            expect(ticket.ticketType).to.eq(0, "ticket is not unknown");

            // check if the rewards are zero
            const reward = await token.getRewardOf(tokenId);
            expect(reward).to.eq(0, "reward is not zero");
        }

        // fulfill the tickets
        await airnodeRrp.mockFulfillWithRange(nextReq);

        // check if the rewards are correct (single)
        for (const tokenId of tokenIds) {
            // check if the ticket is "try again"
            const ticket = await token.getTicket(tokenId)
            expect(ticket.ticketType).to.eq(1, "ticket is not try again");

            // check if the rewards are zero
            const reward = await token.getRewardOf(tokenId);
            expect(reward).to.eq(0, "reward is not zero");
        }

        // check if the rewards are correct (total)
        const rewards = await token.getRewardsOf(signerA.address, 0);
        expect(rewards).to.eq(0, "total rewards is not zero");
    });

    ///
    /// Should allow users to claim their tickets with correct rewards and reset their tickets
    ///

    it("should allow users to claim their tickets with correct rewards and reset their tickets", async function () {
        const {token, uniswap} = await loadFixture(tradeFixture);
        const [,signerA] = await ethers.getSigners();

        // set decrease period to 1 day
        await token.setPeriod(86400);

        // increase the prize pool by sending eth to the contract
        await signerA.sendTransaction({
            to: token.address,
            value: ethers.utils.parseEther("1")
        });

        // buy tokens with signerA
        const tx = await buyTokens(
            uniswap.router02.connect(signerA),
            token.address,
            ethers.utils.parseEther("0.01")
        );

        // find token ids
        const tokenIds = await findTokenIds(tx.hash);
        expect(tokenIds.length).to.gt(0, "no tokens found");

        // override the first 6 ticket to be tier 2-6
        let tier = 2; // start from bronze
        for (const tokenId of tokenIds.slice(0, 5)) {
            const probability = await token.ticketProbability(tier);
            const seedRequired = seedForProbability(tokenId, probability);
            await token.setTicketSeed(seedRequired, tokenId, false);

            // expect ticket to have correct type
            const ticket = await token.getTicket(tokenId);
            expect(ticket.ticketType).to.eq(tier, "ticket type is not correct");

            // expect ticket to have correct reward
            const reward = await token.getRewardOf(tokenId);
            expect(reward).to.gt(0, "reward is not correct");
            tier += 1;
        }

        // check if rewards are higher for higher tier tickets
        let previousReward = BigNumber.from(0);
        for (const tokenId of tokenIds.slice(0, 5)) {
            // get the reward of the ticket
            const reward = await token.getRewardOf(tokenId);
            expect(reward).to.gt(previousReward, "reward is not higher than previous");
            previousReward = reward;
        }

        const previousTotalRarity = await token.totalTicketProbabilities();

        // claim the bronze ticket
        const bronzeReward = await token.getRewardOf(tokenIds[0]);
        await expect(
            token.connect(signerA).claimReward(tokenIds[0])
        )
            .to.emit(token, "RewardClaimed").withArgs(signerA.address, tokenIds[0], bronzeReward)
            .to.changeTokenBalances(uniswap.weth9, [signerA], [bronzeReward]);

        // expect the total rarity to be decrease
        const newTotalRarity = await token.totalTicketProbabilities();
        expect(newTotalRarity).to.lt(previousTotalRarity, "total rarity is not decreased");

        // expect the ticket to be reset
        const ticket = await token.getTicket(tokenIds[0]);
        expect(ticket.ticketType).to.eq(1, "ticket is not try again");

        // claim the other tickets
        const newTotalRewards = await token.getRewardsOf(signerA.address, 0);
        await expect(
            token.connect(signerA).claimRewards(0)
        )
            .to.emit(token, "RewardsClaimed")
            .to.changeTokenBalances(uniswap.weth9, [signerA], [newTotalRewards]);

        // expect all tickets to be reset
        for (const tokenId of tokenIds.slice(1, 5)) {
            const ticket = await token.getTicket(tokenId);
            expect(ticket.ticketType).to.eq(1, "ticket is not try again");
        }

        // expect total rewards to be zero
        const newRewards = await token.getRewardsOf(signerA.address, 0);
        expect(newRewards).to.eq(0, "total rewards is not zero");
    });

    ///
    /// Should decrease the ticket reward 2.5% per day until 40 days
    ///

    it("should decrease the ticket reward 2.5% per day until 40 days", async function () {
        const {token, uniswap} = await loadFixture(tradeFixture);
        const [,signerA] = await ethers.getSigners();

        // set decrease period to 1 day
        await token.setPeriod(86400);

        // increase the prize pool by sending eth to the contract
        await signerA.sendTransaction({
            to: token.address,
            value: ethers.utils.parseEther("1")
        });

        // buy tokens with signerA
        const tx = await buyTokens(
            uniswap.router02.connect(signerA),
            token.address,
            ethers.utils.parseEther("0.01")
        );

        // find token ids
        const tokenIds = await findTokenIds(tx.hash);
        expect(tokenIds.length).to.gt(0, "no tokens found");

        // override the first 6 ticket to be tier 2-6
        let tier = 2; // start from bronze
        for (const tokenId of tokenIds.slice(0, 5)) {
            const probability = await token.ticketProbability(tier);
            const seedRequired = seedForProbability(tokenId, probability);
            await token.setTicketSeed(seedRequired, tokenId, false);

            // expect ticket to have correct type
            const ticket = await token.getTicket(tokenId);
            expect(ticket.ticketType).to.eq(tier, "ticket type is not correct");

            // expect ticket to have correct reward
            const reward = await token.getRewardOf(tokenId);
            expect(reward).to.gt(0, "reward is not correct");
            tier += 1;
        }

        // check prize and iterate the timestamp 1 day
        let initialReward = await token.getRewardOf(tokenIds[0]);
        for (let i = 0; i < 40; i++) {
            // check the total prize pool
            const prizePool = await token.totalPrizePool();
            expect(prizePool).to.gt(0, "prize pool is zero");

            // check the rewards of the tickets
            for (const tokenId of tokenIds.slice(0, 5)) {
                const reward = await token.getRewardOf(tokenId);
                expect(reward).to.gt(0, "reward is zero");
            }

            // check rewards
            const decreasedReward = await token.getRewardOf(tokenIds[0]);
            if (i !== 0) {
                // expect the rewards to be decreased
                const decrease = initialReward.mul(BigNumber.from(i)).mul(25).div(1000);
                expect(decreasedReward).to.eq(initialReward.sub(decrease), "rewards is not decreased");
            }

            // iterate the timestamp 1 day
            await ethers.provider.send("evm_increaseTime", [86400]);
            await ethers.provider.send("evm_mine", []);
        }

        // iterate the timestamp 1 day
        await ethers.provider.send("evm_increaseTime", [8640000]);
        await ethers.provider.send("evm_mine", []);

        // check the rewards of the tickets
        const last = await token.getRewardOf(tokenIds[0]);
        await expect(last).to.eq(0, "reward is not zero");

        // expect ticket types to be reset
        for (const tokenId of tokenIds.slice(0, 5)) {
            const ticket = await token.getTicket(tokenId);
            expect(ticket.ticketType).to.eq(1, "ticket is not try again");
        }
    });
});
