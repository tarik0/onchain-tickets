import {artifacts, ethers} from "hardhat";
import {expect} from "chai";

describe("Deployment", function () {
    ///
    /// The contract should have a bytecode size less than 24576 bytes
    ///

    it("should have bytecode size less than 24576 bytes", async function () {
        const artifact = await artifacts.readArtifact("Tickets404");
        const len = (artifact.deployedBytecode.length - 2) / 2;
        expect(len).to.be.lessThan(24576, "Contract bytecode size is too large");
    });

    ///
    /// The contract should be able to deploy without any revert in the constructor
    ///

    it("should be able to deploy", async function () {
        const _token = await ethers.getContractFactory("Tickets404");
        const token = await _token.deploy();
        await token.deployed();
    });

    ///
    /// The contract should have the correct default states after deployment
    ///

    it("should have the correct default states", async function () {
        const _token = await ethers.getContractFactory("Tickets404");
        const token = await _token.deploy();
        await token.deployed();

        expect(await token.name()).to.equal("Onchain Tickets");
        expect(await token.symbol()).to.equal("TICKET");
    });
});
