// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISecondaryMarket {
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

    event PurchaseProduct(
        string productCode,
        string productName,
        uint256 quantity,
        uint256 value,
        address indexed initiator
    );

    event CreateProduct(
        string productCode,
        string productName,
        uint256 price,
        uint256 quantity,
        address indexed initiator
    );
}