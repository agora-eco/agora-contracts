/*
[alice, bob]: Signer[] = [Wallet 1, Wallet 2]

Alice creates store ✔
Bob purchases product X

Alice creates product w/ stock 1 ✔
Bob creates product X

Bob purchases product ✔
Alice funds rise ✔
Bobs funds decrease ✔
Stock drops 1 ✔

Product stock = 0 ✔
bob purchases product X
Bob restocks X
Alice restocks ✔
Product stock reflects ✔

Bob purchases product ✔

*/

/* const { expect } = require("chai");
const { ethers } = require("hardhat");
import { Signer } from "ethers";
import { Market } from "../src/Types/Market";

describe("Market", () => {
	let accounts: Signer[];
	let market: Market;
	let alice: Signer, bob: Signer;

	before(async () => {
		[alice, bob] = await ethers.getSigners();
	});

	describe("Deploy market", () => {
		it("deploy", async () => {
			const Market = await ethers.getContractFactory("Market");
			market = await Market.deploy();
			const initializeTxn = await market.initialize(
				"RBM",
				"Rich Boy Market"
			);
			await initializeTxn.wait();
		});
	});

	describe("Multirole", () => {
		it("grant", async () => {
			const bobAddress = await bob.getAddress();
			const aliceGrantBobTxn = await market
				.connect(alice)
				.manageRole(bobAddress, true);

			await aliceGrantBobTxn.wait();

			const adminRole = await market.ADMIN_ROLE();
			const bobIsAdmin = await market.hasRole(adminRole, bobAddress);
			expect(bobIsAdmin).to.equal(true);
		});

		it("revoke", async () => {
			const bobAddress = await bob.getAddress();
			const aliceGrantBobTxn = await market
				.connect(alice)
				.manageRole(bobAddress, false);
			await aliceGrantBobTxn.wait();

			const adminRole = await market.ADMIN_ROLE();
			const bobIsAdmin = await market.hasRole(adminRole, bobAddress);
			expect(bobIsAdmin).to.equal(false);
		});
	});

	describe("Establish catalog", () => {
		it("owner create product", async () => {
			const aliceCreateProductTxn = await market
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
			const bobCreateProductTxn = market
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

	describe("Inspect catalog", () => {
		it("valid item lookup", async () => {
			const milkshake = await market.inspectItem("MS");
			await expect(milkshake).to.eql([
				true, // exists
				ethers.BigNumber.from((1 * 10 ** 17).toString()), // price
				"Milkshake", // name
				ethers.BigNumber.from(1), // quantity
				await alice.getAddress(), // owner
				false, // locked
			]);
		});

		it("invalid item lookup", async () => {
			await expect(market.inspectItem("BMS")).to.be.revertedWith(
				"product dne"
			);
		});
	});

	describe("Purchase item", () => {
		it("invalidate excess stock purchase", async () => {
			const bobPurchaseTxn = market.connect(bob).purchase("MS", 10, {
				value: (10 * 0.1 * 10 ** 18).toString(),
			});
			await expect(bobPurchaseTxn).to.be.revertedWith(
				"insufficient stock"
			);
		});

		it("invalidate insufficient value purchase", async () => {
			const bobPurchaseTxn = market.connect(bob).purchase("MS", 1, {
				value: 0,
			});
			await expect(bobPurchaseTxn).to.be.revertedWith(
				"insufficient funds"
			);
		});

		it("valid item purchase", async () => {
			const bobPurchaseTxn = await market.connect(bob).purchase("MS", 1, {
				value: (0.1 * 10 ** 18).toString(),
			});
			await bobPurchaseTxn.wait();

			const milkshake = await market.inspectItem("MS");
			await expect(milkshake).to.eql([
				true,
				ethers.BigNumber.from((1 * 10 ** 17).toString()),
				"Milkshake",
				ethers.BigNumber.from(0),
				await alice.getAddress(),
				false,
			]);
		});

		// decreasing funds

		it("invalidate out of stock item purchase", async () => {
			const bobPurchaseTxn = market.connect(bob).purchase("MS", 1, {
				value: 0,
			});
			await expect(bobPurchaseTxn).to.be.revertedWith("product oos");
		});
	});

	describe("Restock", () => {
		it("disallow non-owner restock", async () => {
			const bobRestockTxn = market
				.connect(bob)
				["restock(string,uint256,bool)"]("MS", 10, true);
			await expect(bobRestockTxn).to.be.revertedWith("must be admin");
		});

		it("owner restock", async () => {
			const aliceRestockTxn = await market["restock(string,uint256)"](
				"MS",
				5
			);
			await aliceRestockTxn.wait();

			const milkshake = await market.inspectItem("MS");
			expect(milkshake).to.eql([
				true,
				ethers.BigNumber.from((1 * 10 ** 17).toString()),
				"Milkshake",
				ethers.BigNumber.from(5),
				await alice.getAddress(),
				false,
			]);
		});
	});
});
 */
