// SPDX-License-Identifier: MIT
/**
    One-way txns only. No reselling facilitated via market, no royalties, etc.
 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import {IMarket} from "./interfaces/IMarket.sol";

contract Market is IMarket, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    address public owner;
    string public name;
    string public symbol;
    string public catalogUri;
    bool public paused;
    mapping(string => Product) internal _catalog;

    // pause event

    modifier productNotExist(string memory productCode) {
        require(
            _catalog[productCode].exists == false,
            "product already exists"
        );
        _;
    }

    modifier isActive() {
        require(paused == false, "market is paused");
        _;
    }

    modifier isAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "must be admin");
        _;
    }

    constructor(string memory _symbol, string memory _name) {
        symbol = _symbol;
        name = _name;
        owner = msg.sender;
        _setupRole(ADMIN_ROLE, msg.sender);

        if (msg.sender != tx.origin) {
            _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
        }

        emit Establish(_symbol, _name, tx.origin);
    }

    function manageRole(address _address, bool state) external {
        if (state) {
            grantRole(ADMIN_ROLE, _address);
        } else {
            revokeRole(ADMIN_ROLE, _address);
        }
    }

    function pause(bool state) external override isAdmin {
        paused = state;
    }

    function create(
        string memory productCode,
        string memory productName,
        uint256 price,
        uint256 quantity
    ) external override isAdmin productNotExist(productCode) {
        _catalog[productCode] = Product(
            true,
            price,
            productName,
            quantity,
            msg.sender
        );

        emit Create(productCode, name, price, quantity, msg.sender);
    }

    function setCatalogUri(string memory _catalogUri)
        external
        override
        isAdmin
    {
        catalogUri = _catalogUri;
    }

    function adjust(
        string memory productCode,
        string memory productName,
        uint256 price
    ) external override isAdmin {
        require(_catalog[productCode].exists == true, "product dne");
        _catalog[productCode] = Product(
            true,
            price,
            productName,
            _catalog[productCode].quantity,
            msg.sender
        );

        emit Adjust(productCode, name, price, msg.sender);
    }

    function purchase(string memory productCode, uint256 quantity)
        external
        payable
        override
        productNotExist(productCode)
        isActive
    {
        Product memory product = _catalog[productCode];

        require(quantity > 0, "invalid quantity");
        require(product.quantity > 0, "product oos");
        require(product.quantity >= quantity, "insufficient stock");
        require(
            quantity * product.price * 10**18 <= msg.value,
            "insufficient funds"
        );

        product.quantity -= quantity;
        _catalog[productCode] = product;

        payable(owner).transfer(product.price);

        emit Purchase(
            productCode,
            product.name,
            quantity,
            product.price * quantity,
            tx.origin
        );
    }

    function restock(string memory productCode, uint256 quantity)
        external
        override
        isAdmin
        productNotExist(productCode)
    {
        Product memory product = _catalog[productCode];

        product.quantity += quantity;
        _catalog[productCode] = product;

        emit Restock(productCode, product.name, quantity, false, msg.sender);
    }

    function restock(
        string memory productCode,
        uint256 quantity,
        bool forced
    ) external override isAdmin productNotExist(productCode) {
        Product memory product = _catalog[productCode];

        if (forced == true) {
            product.quantity = quantity;
        } else {
            product.quantity += quantity;
        }
        _catalog[productCode] = product;

        emit Restock(productCode, product.name, quantity, forced, msg.sender);
    }

    function inspectItem(string calldata productCode)
        external
        view
        override
        returns (Product memory)
    {
        Product memory product = _catalog[productCode];

        require(product.exists == true, "product dne");

        return product;
    }
}