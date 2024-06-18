import { expect } from "chai";
import { ethers } from "hardhat";
import fs from "fs";

describe("Renderer", function () {
    const example = {
        tokenId: "1",
        seed: "123",
        ticketType: "1",
        timestamp: "15",
        owner: ethers.constants.AddressZero,
    };

    async function deploy() {
        const _style = await ethers.getContractFactory("RendererStyle");
        const style = await _style.deploy();
        await style.deployed();

        const renderer = await ethers.getContractFactory("MetadataRenderer");
        const nftRenderer = await renderer.deploy(style.address);

        await nftRenderer.deployed();
        return nftRenderer;
    }

    async function saveSVG(svg: string, filename: string) {
        fs.writeFileSync(filename, svg);
    }

    it("should render SVG images", async function () {
        const nftRenderer = await deploy();
        const svg = await nftRenderer.renderSVGBase64(example);
        expect(svg).to.be.a("string");

        // save SVG to file
        for (let i = 0; i < 7; i++) {
            let svg = await nftRenderer.renderSVG({ ...example, ticketType: i });
            await saveSVG(svg, `./renders/${i}.svg`);
        }
    });

    it("should render attributes JSON metadata", async function () {
        const nftRenderer = await deploy();
        const metadata = await nftRenderer.renderAttributes(example.ticketType);
        expect(metadata).to.be.a("string");

        // parse JSON
        JSON.parse(metadata);
    });

    it("should render correct URI", async function () {
        const nftRenderer = await deploy();
        const metadata = await nftRenderer.renderURI(example);
        expect(metadata).to.be.a("string");
    });
});
