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

contract Secondary is Market, ISecondaryMarket {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _listingId;
    uint256 public marketplaceFee;
    mapping(uint256 => Listing) _listings;
    mapping(address => mapping(string => uint256)) _holdingsBook;

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

    function createListing(string memory productCode, uint256 price, uint256 quantity)
        external
        isActive
        returns (uint256)
    {
        require(quantity > 0, "invalid quantity");
        require(_holdingsBook[_msgSender()][productCode] >= quantity, "Insufficient Holdings Count");
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
            _msgSender()
        );

        _holdingsBook[_msgSender()][productCode] -= quantity;

        emit CreateListing(
            productCode,
            product.name,
            price,
            newListingId,
            _msgSender()
        );
        return newListingId;
    }

    function list(uint256 listingId, bool state) external isActive {
        Listing memory listing = _listings[listingId];
        require(listing.exists == true, "listing dne");
        require(listing.settled == false, "listing settled");

        listing.active = state;
        _listings[listingId] = listing;

        // need event to reflect removing listing
    }

    function purchaseListing(uint256 listingId, uint256 quantity)
        external
        payable
        isActive
    {
        Listing memory listing = _listings[listingId];
        require(listing.exists == true, "listing dne");
        require(listing.owner != _msgSender(), "owner");
        require(listing.active == true, "listing inactive");
        require(listing.settled == false, "listing settled");
        require(listing.price <= msg.value, "insufficient funds");

        uint256 marketCut = msg.value.mul(marketplaceFee.div(100));
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

    function purchaseProduct(string calldata productCode, uint256 quantity)
        external
        payable
        productExist(productCode)
        isActive
    {
        _targetProduct = _catalog[productCode];
        _purchase(productCode, quantity);

        uint256 marketCut = msg.value.mul(marketplaceFee.div(100));
        payable(_targetProduct.owner).transfer(msg.value - marketCut);
        payable(owner).transfer(marketCut);

        _targetProduct.quantity += quantity;
        _holdingsBook[_msgSender()][productCode] += quantity;
    }

    function adjust(uint256 listingId, uint256 price) external {
        Listing memory listing = _listings[listingId];
        require(listing.exists == true, "listing dne");
        require(listing.owner == _msgSender(), "not owner");
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

    function inspectHoldingCount(address owner, string memory productCode)
        external
        view
        returns (uint256)
    {
        require(_holdingsBook[owner][productCode] > 0, "Proudct dne");
        return _holdingsBook[owner][productCode];
    }
}
