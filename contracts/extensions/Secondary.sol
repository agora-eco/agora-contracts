// SPDX-License-Identifier: MIT
/** 
    Users can relist products and market owner gets a fee.
*/

pragma solidity ^0.8.0;

import {Market} from "../base/Market.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Secondary is Market {
    uint256 public marketplaceFee;
    // Mapping from string of product codes to Product struct
    mapping(string => Product[]) private _catalog_secondary;
    mapping (address => mapping(string => uint256)) public _holdingsBook; // owner => product code => n_holdings

    function initialize(
        string memory _symbol,
        string memory _name,
        uint256 _marketplaceFee
    ) 
    public 
    virtual 
    initializer {
        __SecondaryMarket_init(_symbol, _name, _marketplaceFee);
    }

    function __SecondaryMarket_init(
        string memory _symbol,
        string memory _name,
        uint256 _marketplaceFee
    ) 
    internal 
    initializer {
        __AccessControl_init_unchained();
        __Market_init_unchained(_symbol, _name);
        __SecondaryMarket_init_unchained(_marketplaceFee);
    }

    function __SecondaryMarket_init_unchained(uint256 _marketplaceFee) 
    internal 
    initializer {
        marketplaceFee = _marketplaceFee;
    }

    /**
     * primary product purchase
     * overriding Market
     * @dev See {IMarket-purchase} 
     */
    function purchase(string calldata productCode, uint256 quantity)
        external
        payable
        virtual
        override
        productExist(productCode)
        isActive
    {
        Product memory product = _catalog[productCode];

        require(quantity > 0, "invalid quantity");
        require(product.quantity > 0, "product oos");
        require(product.quantity >= quantity, "insufficient stock");
        require(quantity * product.price <= msg.value, "insufficient funds");

        product.quantity -= quantity;
        _catalog[productCode] = product;

        uint256 marketCut = msg.value * marketplaceFee / 100; // value * (marketplaceFee / 100)
        payable(product.owner).transfer(product.price - marketCut);
        payable(owner).transfer(marketCut);

        _holdingsBook[msg.sender][productCode] += quantity;

        emit Purchase(
            productCode,
            product.name,
            quantity,
            product.price * quantity,
            _msgSender()
        );
    }

    /**
     * secondary create
     * @dev See {IMarket-create}
     */
    function create(
        string memory productCode,
        uint256 price,
        uint256 quantity
    ) 
    public
    virtual
    {
        require(_holdingsBook[msg.sender][productCode] >= quantity, "selling more than you own");
        Product memory product = _catalog[productCode];
        string memory productName = product.name;
        _catalog_secondary[productCode].push(Product(
            true,
            price,
            productName,
            quantity,
            _msgSender(),
            false
        ));
        _holdingsBook[msg.sender][productCode] -= quantity;

        emit Create(productCode, productName, price, quantity, _msgSender());
    }

    function purchase_secondary(string calldata productCode, uint256 quantity)
        external
        payable
        virtual
        productExist(productCode)
    {
        uint256 product_length = _catalog_secondary[productCode].length;
        purchase_secondary(productCode, product_length - 1, quantity);
    }

    /**
     * secondary product purchase
     * @dev See {IMarket-purchase} 
     */
    function purchase_secondary(string calldata productCode, uint256 productIndex, uint256 quantity)
        public
        payable
        productExist(productCode)
    {
        uint256 product_length = _catalog_secondary[productCode].length;
        require(productIndex < product_length, "product index out of bound");
        Product memory product = _catalog_secondary[productCode][productIndex];

        require(quantity > 0, "invalid quantity");
        require(product.quantity > 0, "product oos");
        require(product.quantity >= quantity, "insufficient stock");
        require(quantity * product.price <= msg.value, "insufficient funds");

        product.quantity -= quantity;
        if (product.quantity == 0) {
            // not sure if it's a safe solution to delete a product
            _catalog_secondary[productCode][productIndex] = _catalog_secondary[productCode][product_length - 1]; 
            _catalog_secondary[productCode].pop();
        } else {
            _catalog_secondary[productCode][productIndex] = product;
        }

        uint256 marketCut = msg.value * marketplaceFee / 100; // value * (marketplaceFee / 100)
        payable(product.owner).transfer(product.price - marketCut);
        payable(owner).transfer(marketCut);

        _holdingsBook[msg.sender][productCode] += quantity;

        emit Purchase(
            productCode,
            product.name,
            quantity,
            product.price * quantity,
            _msgSender()
        );
    }
    
}
