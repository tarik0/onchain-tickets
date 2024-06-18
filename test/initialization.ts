import {ethers} from "hardhat";
import {expect} from "chai";
import {loadFixture} from "@nomicfoundation/hardhat-network-helpers";
import {
    deployMirror,
    deployMockedAirnodeRrp,
    deployReferrals,
    deployRenderer,
    deployToken,
} from "./util/deployContract";
import {tradeFixture} from "./util/uniswap";

describe("Initialization", function () {
    ///
    /// Should not allow transfer before initialization
    /// - even the owner can't transfer tokens before DN404 initialization
    /// - other users can't transfer tokens before all initializations are done
    ///

    it("should not allow transfer before initialization", async function () {
        const token = await deployToken();
        const signers = await ethers.getSigners();

        // transfer tokens from owner to another address
        await expect(
            token.transfer(signers[2].address, 1)
        ).to.reverted;
    });

    ///
    /// Should initialize the DN404 and set total supply etc.
    /// - owner can add liquidity after DN404 initialization
    /// - should also set QRND settings correctly
    ///

    it("should initialize the DN404 and QRND", async function () {
        const token = await deployToken();
        const referrals = await deployReferrals(token.address, await token.signer.getAddress());
        const { renderer } = await deployRenderer();
        const mirror = await deployMirror();
        const {
            airnodeRrp, airnode, sponsor, endpoint
        } = await loadFixture(deployMockedAirnodeRrp);

        // initialize DN404
        await expect(token.initializeToken({
            AirnodeRrp: airnodeRrp.address,
            Airnode: airnode,
            SponsorWallet: sponsor,
            EndpointIdUint256: endpoint
        }, mirror.address, renderer.address, referrals.address)).to.not.reverted;

        // transfer tokens from owner to another address
        const signers = await ethers.getSigners();
        await token.transfer(signers[2].address, 1);

        // check balance of the receiver
        expect(await token.balanceOf(signers[2].address)).to.equal(1);

        // transfer tokens to another user
        await expect(
            token.connect(signers[2]).transfer(signers[3].address, 1)
        ).to.revertedWithCustomError(token, "NotInitialized");

        // check if the QRND is initialized
        const [
            airnodeRrp_, airnode_, sponsorWallet_, endpointIdUint256_
        ] = await token.requestSettings();

        expect(airnodeRrp_).to.equal(airnodeRrp.address);
        expect(airnode_).to.equal(airnode);
        expect(sponsorWallet_).to.equal(sponsor);
        expect(endpointIdUint256_).to.equal(endpoint);
    });

    ///
    /// Should initialize the pair & allow transfer
    ///

    it("should initialize the pair & allow transfer", async function () {
        const { token } = await tradeFixture();

        // check if the pair is initialized
        expect(
            await token.pool()
        ).to.not.equal(ethers.constants.AddressZero);

        // transfer tokens from owner to another address
        const signers = await ethers.getSigners();
        await token.transfer(signers[2].address, 1);

        // transfer tokens back to owner
        await expect(
            token.connect(signers[2]).transfer(signers[0].address, 1)
        ).to.not.reverted;
    });
});