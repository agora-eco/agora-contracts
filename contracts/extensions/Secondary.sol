// SPDX-License-Identifier: MIT
/** 
    Users can relist products and market owner gets a fee.
*/

pragma solidity ^0.8.0;

import {ISecondaryMarket} from "../base/interfaces/ISecondaryMarket.sol";
import {IMarket} from "../base/interfaces/IMarket.sol";
import {Market} from "../base/Market.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Secondary is Market, ISecondaryMarket{
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _listingId;
    uint256 public marketplaceFee;
    mapping (uint256 => Listing) _listings;
    mapping (address => mapping(string => Product)) _holdingsBook; // owner => product code => struct Product

    function initialize(
        string memory _symbol,
        string memory _name,
        uint256 _marketplaceFee
    ) public virtual initializer {
        __SecondaryMarket_init(_symbol, _name, _marketplaceFee);
    }

    function __SecondaryMarket_init(
        string memory _symbol,
        string memory _name,
        uint256 _marketplaceFee
    ) internal initializer {
        __AccessControl_init_unchained();
        __Market_init_unchained(_symbol, _name);
        __SecondaryMarket_init_unchained(_symbol, _name, _marketplaceFee);
    }

    function __SecondaryMarket_init_unchained(
        string memory _symbol,
        string memory _name,
        uint256 _marketplaceFee
    ) internal initializer {
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

    function purchaseProduct(string memory productCode, uint256 quantity)
        external
        payable
        virtual
        isActive
    {
        Product memory product = _holdingsBook[msg.sender][productCode];
        require(_catalog[productCode].exists == true, "Product Does Not Exist In Catalog");
        require(product.exists == true, "Product Does Not Exist In Holdings Book");
        require(product.price * quantity <= msg.value, "Insufficient Funds");

        uint256 marketCut = msg.value.mul(marketplaceFee.div(100));
        payable(product.owner).transfer(msg.value - marketCut);
        payable(owner).transfer(marketCut);

        product.quantity += quantity;
        _holdingsBook[msg.sender][productCode] = product;

        emit PurchaseProduct(
            productCode,
            product.name,
            quantity,
            product.price * quantity,
            _msgSender()
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

    function inspectProduct(string memory productCode) 
        external
        view
        returns (Product memory)    
    {
        return _holdingsBook[msg.sender][productCode];
    }

    function createProduct(
        string calldata productCode,
        string calldata productName,
        uint256 price,
        uint256 quantity
    ) external virtual isAdmin {
        require(_holdingsBook[msg.sender][productCode].exists == false, "Product Already Exists");

        _holdingsBook[msg.sender][productCode] = Product(
            true,
            price,
            productName,
            quantity,
            _msgSender(),
            false
        );

        emit CreateProduct(productCode, productName, price, quantity, _msgSender());
    }
}
