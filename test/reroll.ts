import {buyTokensWithOutput, findTokenIds, tradeFixture} from "./util/uniswap";
import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {ethers} from "hardhat";
import {expect} from "chai";

describe("Re-roll", function () {
    ///
    /// Should re-roll for "try again" tickets with fee
    ///

    it("should re-roll for 'try again' tickets with fee", async function () {
        const {token, uniswap, airnodeRrp, referrals, defaultReferrer}
            = await loadFixture(tradeFixture);
        const [,signerA, signerB] = await ethers.getSigners();

        // set probabilities to max
        await token.setProbabilities({
            Bronze: 2**32 - 5,
            Silver: 2**32 - 4,
            Gold: 2**32 - 3,
            Diamond: 2**32 - 2,
            Emerald: 2**32 - 1,
        })

        // buy tokens with signerA
        const maxTicketRefresh = await token.maxTicketRefresh();
        const reqId = await airnodeRrp.nextRequestId();
        const tx = await buyTokensWithOutput(
            uniswap.router02.connect(signerA),
            token.address,
            maxTicketRefresh.mul(ethers.constants.WeiPerEther)
        );

        // add balance to signerA
        await ethers.provider.send("hardhat_setBalance", [
            signerA.address,
            "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        ]);

        // mock fulfillment success
        const logs = await token.queryFilter(
            token.filters.SeedRequestedForRange()
        );
        expect(logs.length).to.eq(1);

        // fulfill requests
        const fulfillTx = await airnodeRrp.mockFulfillWithRange(reqId);
        await fulfillTx.wait();

        // find token ids
        let tokenIds = await findTokenIds(tx.hash);
        expect(tokenIds.length).to.gt(0, "no tokens found");
        tokenIds = tokenIds.slice(1, tokenIds.length);

        // validate the tickets
        for (const tokenId of tokenIds) {
            const ticket = await token.getTicket(tokenId);
            expect(ticket.ticketType).to.eq(1, "ticket is not try again");
            expect(ticket.owner).to.eq(signerA.address, "ticket owner is not signerA");
        }

        const ticketRefreshFee = await token.ticketRefreshFee();
        const totalFee = ticketRefreshFee.mul(tokenIds.length);
        const treasuryFee = totalFee.mul(675).div(1000);  // 67.5% fee of the 10% fee
        const referrerFee = totalFee.mul(75).div(1000);  // 7.5% fee of the 10% fee

        // use signerB as referral
        await referrals.connect(signerA).setReferral(signerB.address);

        // try to re-roll the tickets
        await expect(
            token.connect(signerA).refreshTickets(tokenIds, {value: totalFee.sub(1)})
        )
            .to
            .revertedWithCustomError(token, "InsufficientFee");

        const defaultRefBal = await ethers.provider.getBalance(defaultReferrer);
        const referrerBeforeBal = await ethers.provider.getBalance(referrals.referrerOf(signerA.address));

        // re-roll the tickets
        const nextReqId = await airnodeRrp.nextRequestId();
        await expect(
            token.connect(signerA).refreshTickets(tokenIds, {value: totalFee, gasPrice: 0})
        )
            .to.emit(token, "SeedRequestedForIds");

        const defaultRefAfter = await ethers.provider.getBalance(defaultReferrer);
        const referrerAfterBal = await ethers.provider.getBalance(referrals.referrerOf(signerA.address));

        expect(defaultRefAfter.sub(defaultRefBal)).to.eq(treasuryFee, "treasury fee is not correct");
        expect(referrerAfterBal.sub(referrerBeforeBal)).to.eq(referrerFee, "referrer fee is not correct");

        const receipt = await airnodeRrp.mockFulfillWithIds(nextReqId).then(tx => tx.wait());
        expect(receipt.gasUsed).to.lte(1_420_000, "gas used is too high");
    });
});
