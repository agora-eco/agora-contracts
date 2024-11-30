// SPDX-License-Identifier: MIT
/** 
    Users can relist products and market owner gets a fee.
*/

pragma solidity ^0.8.0;

import {Market} from "../base/Market.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Secondary is Market {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _listingId;
    uint256 public marketplaceFee;
    mapping(uint256 => Listing) _listings;

    struct Listing {
        bool exists;
        bool active;
        bool settled;
        string productCode;
        string name;
        uint256 price;
        address owner;
    }

    event List(
        string productCode,
        string productName,
        uint256 price,
        uint256 listingId,
        address indexed initiator
    );

    // fee adjust event

    constructor(
        string memory _symbol,
        string memory _name,
        uint256 _marketplaceFee
    ) Market(_symbol, _name) {
        marketplaceFee = _marketplaceFee;
    }

    function adjustFees(uint256 fees) external isAdmin {
        require(fees >= 0 && fees <= 100, "fees outside of range");
        marketplaceFee = fees;
    }

    function list(string memory productCode, uint256 price)
        external
        isActive
        returns (uint256)
    {
        Product memory product = _catalog[productCode];
        require(product.exists == true, "product dne");

        _listingId.increment();
        uint256 newListingId = _listingId.current();

        _listings[newListingId] = Listing(
            true,
            true,
            false,
            productCode,
            product.name,
            price,
            msg.sender
        );

        emit List(productCode, product.name, price, newListingId, msg.sender);
        return newListingId;
    }

    function list(uint256 listingId, bool state) external isActive {
        Listing memory listing = _listings[listingId];
        require(listing.exists == true, "listing dne");
        require(listing.settled == false, "listing settled");

        listing.active = state;
        _listings[listingId] = listing;
    }

    function purchase(uint256 listingId) external payable virtual isActive {
        Listing memory listing = _listings[listingId];
        require(listing.exists == true, "listing dne");
        require(listing.owner != msg.sender, "owner");
        require(listing.active == true, "listing inactive");
        require(listing.settled == false, "listing settled");
        require(listing.price <= msg.value, "insufficient funds");

        uint256 marketCut = msg.value.mul(marketplaceFee.div(100)); // value * (marketplaceFee / 100)
        payable(listing.owner).transfer(msg.value - marketCut);
        payable(owner).transfer(marketCut);

        listing.active = false;
        listing.settled = true;
        _listings[listingId] = listing;

        emit Purchase(
            listing.productCode,
            listing.name,
            1,
            listing.price,
            tx.origin
        );
    }

    function adjust(uint256 listingId, uint256 price) external {
        Listing memory listing = _listings[listingId];
        require(listing.exists == true, "listing dne");
        require(listing.owner == msg.sender, "not owner");
        require(listing.settled == false, "listing settled");

        listing.price = price;
        _listings[listingId] = listing;
    }

    function inspectListing(uint256 listingId)
        external
        view
        returns (Listing memory)
    {
        return _listings[listingId];
    }
}
