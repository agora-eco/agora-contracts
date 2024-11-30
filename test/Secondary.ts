const { expect } = require("chai");
const { ethers } = require("hardhat");
import { Signer } from "ethers";
import { MarketFactory } from "../src/Types/MarketFactory";
import { Market } from "../src/Types/Market";
import { Secondary } from "../src/Types/Secondary";

describe("Secondary", () => {
	let alice: Signer, bob: Signer;
	let secondary: Secondary;
	let marketFactory: MarketFactory;
	let market: Market;
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
		it("Deploy Default Market", async () => {
			const Market = await ethers.getContractFactory("Market");
			market = await Market.deploy();
		});
		it("Deploy Secondary Market", async () => {
			const Secondary = await ethers.getContractFactory("Secondary");
			secondary = await Secondary.deploy();
		});
		it("Add Default Market Extension", async () => {
			const addDefaultMarketExtensionTx = await marketFactory
				.connect(alice)
				.addExtension("Default Market", market.address);
			await addDefaultMarketExtensionTx.wait();
		});
		it("Add Secondary Market Extension", async () => {
			const addSecondaryMarketExtensionTx = await marketFactory
				.connect(alice)
				.addExtension("Secondary", secondary.address);
			await addSecondaryMarketExtensionTx.wait();
		});
	});

	describe("Manage Market", () => {
		it("Deploy", async () => {
			const iface = new ethers.utils.Interface([
				"function initialize(string _symbol, string _name, uint256 _marketplaceFee)",
			]);
			const createMarketTxn = await marketFactory
				.connect(alice)
				.deployMarket(
					1,
					iface.encodeFunctionData("initialize", [
						"TPM",
						"Test Proxied Market",
						1,
					])
				);

			await createMarketTxn.wait();
		});

		it("Retrieve", async () => {
			const newMarketAddress = await marketFactory.markets(0);
			secondary = await ethers.getContractAt(
				"Secondary",
				newMarketAddress
			);
			expect(await secondary.owner()).to.equal(await alice.getAddress());
		});
	});

	describe("Establish catalog", () => {
		it("owner create product", async () => {
			const aliceCreateProductTxn = await secondary
				.connect(alice)
				["create(string,string,uint256,uint256)"](
					"MS",
					"Milkshake",
					(1 * 10 ** 17).toString(),
					1
				);
			await aliceCreateProductTxn.wait();
		});

		it("disallow non-owner create product", async () => {
			const bobCreateProductTxn = secondary
				.connect(bob)
				["create(string,string,uint256,uint256)"](
					"BMS",
					"Bad Milkshake",
					(1 * 10 ** 17).toString(),
					1
				);
			await expect(bobCreateProductTxn).to.be.revertedWith(
				"must be admin"
			);
		});
	});

	describe("Purchase Item", () => {
		it("Primary Item Purchase", async () => {
			const bobPurchaseTxn = await secondary.connect(bob).purchase("MS", 1, {
				value: ethers.BigNumber.from((0.1 * 10 ** 18).toString()),
			});
			await bobPurchaseTxn.wait();

			const milkshake = await secondary.inspectItem("MS");
			await expect(milkshake).to.eql([
				true,
				ethers.BigNumber.from((0.1 * 10 ** 18).toString()), // price
				"Milkshake",
				ethers.BigNumber.from(0), // quantity
				await alice.getAddress(), // owner
				false,
			]);
			let holdingsBook = await secondary._holdingsBook(await bob.getAddress(), "MS");
			await expect(holdingsBook).to.eql(ethers.BigNumber.from(1));
		});
	});

	describe("Add secondary products to catalog", () => {
		it("non-owner create secondary product", async () => {
			const bobCreateSecondaryProductTxn = await secondary
				.connect(bob)
				["create(string,uint256,uint256)"](
					"MS",
					(1 * 10 ** 17).toString(),
					1
				);
			await bobCreateSecondaryProductTxn.wait();
			let holdingsBook = await secondary._holdingsBook(await bob.getAddress(), "MS");
			await expect(holdingsBook).to.eql(ethers.BigNumber.from(0));
		});

		it("non-owner create secondary product they didn't purchase", async () => {
			const bobCreateSecondaryProductTxn2 = secondary
				.connect(bob)
				["create(string,uint256,uint256)"](
					"MS",
					(1 * 10 ** 17).toString(),
					1
				);
			await expect(bobCreateSecondaryProductTxn2).to.be.revertedWith(
				"selling more than you own"
			);
		});
	});

	describe("Purchase Item", () => {
		it("Secondary Item Purchase", async () => {
			const alicePurchaseTxn = await secondary.connect(alice)["purchase_secondary(string,uint256)"]("MS", 1, {
				value: ethers.BigNumber.from((0.1 * 10 ** 18).toString()),
			});
			await alicePurchaseTxn.wait();
		});
	});
});
