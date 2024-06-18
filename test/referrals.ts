import {ethers} from "hardhat";
import {expect} from "chai";
import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {tradeFixture} from "./util/uniswap";
import {Contract} from "ethers";
import {Referrals} from "../typechain-types";

describe("Referrals", function () {
    ///
    /// Returns the referral contract
    ///

    function getReferralContract(token: Contract) : Referrals {
        return token.helperContracts()
            .then((addresses: any) => {
                return ethers.getContractAt("Referrals", addresses.referrals);
            });
    }

    ///
    /// Should have the correct default referrer
    ///

    it("should have the correct default referrer", async function () {
        const {token, defaultReferrer} = await loadFixture(tradeFixture);

        // check if the default referrer is set
        const [, referrerContract] = await token.helperContracts();
        expect(referrerContract).to.not.eq(ethers.constants.AddressZero);

        // cast to contract
        const referrer = await ethers.getContractAt("Referrals", referrerContract);
        expect(defaultReferrer).to.eq(await referrer.defaultReferrer());
    });

    ///
    /// Should allow users to set their own referrer
    ///

    it("should allow users to set their own referrer", async function () {
        const {token} = await loadFixture(tradeFixture);
        const [,signerA, signerB] = await ethers.getSigners();
        const referralContract = await getReferralContract(token);

        // set signerA as the referrer for signerB
        await expect(
            referralContract.connect(signerB).setReferral(signerA.address)
        ).to.emit(referralContract, "ReferralSet");

        // check if the referrer is set
        const referrer = await referralContract.referrerOf(signerB.address);
        expect(referrer).to.eq(signerA.address);
    });

    ///
    /// Should not allow users to set an empty referrer or themselves as the referrer
    ///

    it("should not allow users to set an empty referrer or themselves as the referrer", async function () {
        const {token} = await loadFixture(tradeFixture);
        const [, signerB] = await ethers.getSigners();
        const referralContract = await getReferralContract(token);

        // set an empty address as the referrer
        await expect(
            referralContract.connect(signerB).setReferral(ethers.constants.AddressZero)
        ).to.be.revertedWithCustomError(referralContract, "InvalidReferrer");

        // set signerB as their own referrer
        await expect(
            referralContract.connect(signerB).setReferral(signerB.address)
        ).to.be.revertedWithCustomError(referralContract, "InvalidReferrer");
    });
});