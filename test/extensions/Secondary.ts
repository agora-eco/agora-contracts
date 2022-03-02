const { expect } = require("chai");
const { ethers } = require("hardhat");
import { Signer } from "ethers";
import { MarketFactory } from "../../src/Types/MarketFactory";
import { Secondary } from "../../src/Types/Secondary";

describe("SecondaryMarket", () => {
    let accounts: Signer[];
    let marketFactory: MarketFactory;
	let secondaryMarket: Secondary;
	let alice: Signer, bob: Signer;
    
    before(async () => {
		[alice, bob] = await ethers.getSigners();
	});

    describe("Deploy MarketFactory", () => {
		it("deploy", async () => {
			const MarketFactory = await ethers.getContractFactory(
				"MarketFactory"
			);
			marketFactory = await MarketFactory.deploy(
				await alice.getAddress()
			);
		});
	});

    describe("Initialize Proxies", () => {
        it("Deploy Secondary Market", async () => {
            const SecondaryMarket = await ethers.getContractFactory("Secondary");
            secondaryMarket = await SecondaryMarket.deploy();
        });

        it("Add Secondary Market Extension", async () => {
            const addSecondaryMarketExtensionTx = await marketFactory
                .connect(alice)
                .addExtension("Secondary", secondaryMarket.address);
            await addSecondaryMarketExtensionTx.wait();
        });
    });

    describe("Manage Market", () => {
		it("Deploy Secondary Market", async () => {
			const iface = new ethers.utils.Interface([
				"function initialize(string _symbol, string _name, uint256 _maxPerOwner)",
			]);
			const createSecondaryMarket = await marketFactory
				.connect(alice)
				.deployMarket(
					"Secondary",
					iface.encodeFunctionData("initialize", [
						"GFM",
						"GweiFace Market",
						ethers.BigNumber.from((2).toString()),
					])
				);

			await createSecondaryMarket.wait();
		});

        it("Retrieve Secondary", async () => {
			const newMarketAddress = await marketFactory.markets(0);
			secondaryMarket = await ethers.getContractAt(
				"Secondary",
				newMarketAddress
			);

			expect(await secondaryMarket.owner()).to.equal(
				await alice.getAddress()
			);
		});
	});

    describe("Establish Holdingsbook", async () => {
        it("Owner Create Product In Secondary Market", async () => {
			const aliceCreateProductTxn = await secondaryMarket
				.connect(alice)
				["create(string,string,uint256,uint256)"](
					"MS",
					"Milkshake",
					ethers.BigNumber.from((0.1 * 10 ** 18).toString()),
					1
				);
			await aliceCreateProductTxn.wait();
		});
    });
    
    describe("Inspect Catalog", async () => {
        it("Inspect Valid Product", async () => {
            const milkshake = await secondaryMarket.connect(alice).inspectItem("MS");
            
            await expect(milkshake).to.eql([
				true,
				ethers.BigNumber.from((0.1 * 10 ** 18).toString()),
				"Milkshake",
				ethers.BigNumber.from(1),
				await alice.getAddress(),
				false,
			]);
        });
    });

    describe("Inspect Holdingsbook", async () => {
        it("Inspect Valid Product", async () => {
            const milkshake = await secondaryMarket.connect(alice).inspectProduct("MS");
            
            await expect(milkshake).to.eql([
				true,
				ethers.BigNumber.from((0.1 * 10 ** 18).toString()),
				"Milkshake",
				ethers.BigNumber.from(1),
				await alice.getAddress(),
				false,
			]);
        });
    });

    describe("Purchase Product", () => {
        it("Valid Product Purchase", async () => {
            const alicePurchaseTxn = await secondaryMarket.connect(alice).purchaseProduct(
                "MS", 1, {
				    value: ethers.BigNumber.from((0.1 * 10 ** 18).toString()),
			    }
            );
            await alicePurchaseTxn.wait();

            const milkshake = await secondaryMarket.inspectItem("MS");
			await expect(milkshake).to.eql([
				true,
				ethers.BigNumber.from((0.1 * 10 ** 18).toString()),
				"Milkshake",
				ethers.BigNumber.from(1),
				await alice.getAddress(),
				false,
			]);
        });
    });
})