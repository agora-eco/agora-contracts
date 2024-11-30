// SPDX-License-Identifier: MIT
/**
    One-way txns only. No reselling facilitated via market, no royalties, etc.
 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IMarket} from "./interfaces/IMarket.sol";
import "hardhat/console.sol";

/**
 * @dev Foundation of a market standard.
 */
contract Market is IMarket, Initializable, AccessControlUpgradeable {
    // Admin role
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Market owner. Original deployer of the market and super admin
    address public owner;

    // Market name
    string private name;

    // Market symbol
    string private symbol;

    // Market catalog URI used for offchain purposes. Where market metadata exists
    string public catalogUri;

    // Market paused
    bool public paused;

    Product internal _targetProduct;

    // Mapping from string of product codes to Product struct
    mapping(string => Product) internal _catalog;

    /**
     * @dev Check if product does not exist in market catalog
     */
    modifier productNotExist(string memory productCode) {
        require(
            _catalog[productCode].exists == false,
            "product already exists"
        );
        _;
    }

    /**
     * @dev Check if product exists in market catalog
     */
    modifier productExist(string memory productCode) {
        require(_catalog[productCode].exists == true, "product dne");
        _;
    }

    /**
     * @dev Check if market is active
     */
    modifier productNotLocked(string memory productCode) {
        require(_catalog[productCode].locked == false, "product is locked");
        _;
    }

    /**
     * @dev Check if market is active
     */
    modifier isActive() {
        require(paused == false, "market is paused");
        _;
    }

    /**
     * @dev Check if txn origin is of admin role
     */
    modifier isAdmin() {
        require(hasRole(ADMIN_ROLE, _msgSender()), "must be admin");
        _;
    }

    /**
     * @dev Initalizes the market by setting a `symbol` and `name` to the market
     * Assigns owner to market and sets up roles
     */
    function initialize(string memory _symbol, string memory _name)
        public
        virtual
        initializer
    {
        __Market_init(_symbol, _name);
    }

    function __Market_init(string memory _symbol, string memory _name)
        internal
        initializer
    {
        __AccessControl_init_unchained();
        __Market_init_unchained(_symbol, _name);
    }

    function __Market_init_unchained(string memory _symbol, string memory _name)
        internal
        initializer
    {
        symbol = _symbol;
        name = _name;
        owner = tx.origin;
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
        _setupRole(ADMIN_ROLE, tx.origin);

        emit Establish(_symbol, _name, owner);
    }

    /**
     * @dev Assign and revoke role from `address` with action dependent on `state`
     */
    function manageRole(address _address, bool state) external {
        if (state) {
            grantRole(ADMIN_ROLE, _address);
        } else {
            revokeRole(ADMIN_ROLE, _address);
        }
    }

    /**
     * @dev See {IMarket-pause}
     */
    function pause(bool state) external override isAdmin {
        paused = state;

        emit Pause(state, _msgSender());
    }

    /**
     * @dev See {IMarket-create}
     */
    function _create(
        string calldata productCode,
        string calldata productName,
        uint256 price,
        uint256 quantity
    ) internal {
        _create(productCode, productName, price, quantity, false);
    }

    function create(
        string calldata productCode,
        string calldata productName,
        uint256 price,
        uint256 quantity
    ) external virtual override isAdmin productNotExist(productCode) {
        _create(productCode, productName, price, quantity, false);
    }

    function _create(
        string memory productCode,
        string memory productName,
        uint256 price,
        uint256 quantity,
        bool locked
    ) internal {
        _catalog[productCode] = Product(
            true,
            price,
            productName,
            quantity,
            _msgSender(),
            locked
        );

        emit Create(productCode, productName, price, quantity, _msgSender());
    }

    /**
     * @dev See {IMarket-create}
     */
    function create(
        string memory productCode,
        string memory productName,
        uint256 price,
        uint256 quantity,
        bool locked
    ) public isAdmin productNotExist(productCode) {
        _create(productCode, productName, price, quantity, locked);
    }

    /**
     * @dev See {IMarket-setCatalogUri}
     */
    function setCatalogUri(string calldata _catalogUri)
        external
        virtual
        override
        isAdmin
    {
        catalogUri = _catalogUri;
    }

    /**
     * @dev See {IMarket-adjust}
     */
    function adjust(
        string memory productCode,
        string memory productName,
        uint256 price
    )
        external
        override
        isAdmin
        productExist(productCode)
        productNotLocked(productCode)
    {
        _catalog[productCode] = Product( // change .price
            true,
            price,
            productName,
            _catalog[productCode].quantity,
            _msgSender(),
            false
        );

        emit Adjust(productCode, productName, price, _msgSender());
    }

    function _purchase(string memory productCode, uint256 quantity)
        internal
        productExist(productCode)
        isActive
    {
        require(_targetProduct.exists, "product dne");
        // store product code in product struct
        require(quantity > 0, "invalid quantity");
        require(_targetProduct.quantity > 0, "product oos");
        require(_targetProduct.quantity >= quantity, "insufficient stock");
        require(
            quantity * _targetProduct.price <= msg.value,
            "insufficient funds"
        );

        _targetProduct.quantity -= quantity;
        _catalog[productCode] = _targetProduct;

        emit Purchase(
            productCode,
            _targetProduct.name,
            quantity,
            _targetProduct.price * quantity,
            _msgSender()
        );
    }

    /**
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
        _targetProduct = _catalog[productCode];
        _purchase(productCode, quantity);
        payable(owner).transfer(_targetProduct.price);
    }

    /**
     * @dev See {IMarket-restock}
     */
    function restock(string memory productCode, uint256 quantity)
        external
        override
        isAdmin
        productExist(productCode)
        productNotLocked(productCode)
    {
        Product memory product = _catalog[productCode];

        product.quantity += quantity;
        _catalog[productCode] = product;

        emit Restock(productCode, product.name, quantity, false, _msgSender());
    }

    /**
     * @dev See {IMarket-restock}
     */
    function restock(
        string memory productCode,
        uint256 quantity,
        bool forced
    )
        external
        override
        isAdmin
        productExist(productCode)
        productNotLocked(productCode)
    {
        Product memory product = _catalog[productCode];

        if (forced == true) {
            product.quantity = quantity;
        } else {
            product.quantity += quantity;
        }
        _catalog[productCode] = product;

        emit Restock(productCode, product.name, quantity, forced, _msgSender());
    }

    /**
     * @dev See {IMarket-inspectItem}
     */
    function inspectItem(string calldata productCode)
        external
        view
        override
        productExist(productCode)
        returns (Product memory)
    {
        Product memory product = _catalog[productCode];

        return product;
    }

    function setMarketName(string memory _name) internal isAdmin {
        name = _name;
    }

    function setMarketSymbol(string memory _symbol) internal isAdmin {
        symbol = _symbol;
    }

    function getMarketName() public view returns (string memory) {
        return name;
    }

    function getMarketSymbol() public view returns (string memory) {
        return symbol;
    }
}
