// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Provenance {
    address public admin;
    mapping(address => Entity) public entities;
    mapping(string => Product) public products;
    mapping(address => string[]) private pendingTransfers;
    address[] public registeredEntities;
    string[] public productSerialNumbers;

    enum Role { Supplier, Producer, Transporter, Warehouse, Market }
    enum ProductStatus { Created, PendingTransfer, Owned }

    event EntityRegistered(address indexed entityAddress, Role role, string name, bool certified);
    event ProductAdded(string serialNo, string name, uint[] locationData, uint timeStamp, address indexed producer);
    event OwnershipTransferred(string serialNo, address indexed previousOwner, address indexed newOwner);

    struct Entity {
        Role role;
        string name;
        string location;
        bool isRegistered;
        bool isCertified;
    }

    struct Product {
        string name;
        uint[] locationData;
        uint timeStamp;
        ProductStatus status;
        address currentHolder;
    }

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    function registerEntity(address _entity, Role _role, string memory _name, string memory _location, bool _certified) public onlyAdmin {
        require(!entities[_entity].isRegistered, "Entity already registered");
        entities[_entity] = Entity(_role, _name, _location, true, _certified);
        registeredEntities.push(_entity);
        emit EntityRegistered(_entity, _role, _name, _certified);
    }

    function certifyEntity(address _entity) public onlyAdmin {
        require(entities[_entity].isRegistered, "Entity not registered");
        entities[_entity].isCertified = true;
    }

    function addProduct(string memory serialNo, string memory _name, uint[] memory _locationData) public {
        require(entities[msg.sender].isRegistered, "Only registered entities can add products");
        require(bytes(serialNo).length != 0, "Serial number cannot be empty");
        require(products[serialNo].timeStamp == 0, "Product already exists");
        
        products[serialNo] = Product(_name, _locationData, block.timestamp, ProductStatus.Created, msg.sender);
        productSerialNumbers.push(serialNo);
        emit ProductAdded(serialNo, _name, _locationData, block.timestamp, msg.sender);
    }

    function transferOwnership(string memory serialNo, address newOwner) public {
        require(products[serialNo].status == ProductStatus.Owned, "Product not owned or already in transfer");
        require(products[serialNo].currentHolder == msg.sender, "Only the current owner can initiate transfer");
        require(entities[newOwner].isRegistered, "New owner is not a registered entity");

        products[serialNo].status = ProductStatus.PendingTransfer;
        pendingTransfers[newOwner].push(serialNo);
    }

    function acceptOwnership(string memory serialNo) public {
        require(isPendingTransfer(serialNo, msg.sender), "No pending transfer for this product to you");
        require(products[serialNo].status == ProductStatus.PendingTransfer, "Product not in transferable state");

        address previousOwner = products[serialNo].currentHolder;
        products[serialNo].currentHolder = msg.sender;
        products[serialNo].status = ProductStatus.Owned;
        removePendingTransfer(serialNo, msg.sender);

        emit OwnershipTransferred(serialNo, previousOwner, msg.sender);
    }

    function isPendingTransfer(string memory serialNo, address user) private view returns (bool) {
        string[] memory userPendingTransfers = pendingTransfers[user];
        for (uint i = 0; i < userPendingTransfers.length; i++) {
            if (keccak256(bytes(userPendingTransfers[i])) == keccak256(bytes(serialNo))) {
                return true;
            }
        }
        return false;
    }

    function removePendingTransfer(string memory serialNo, address user) private {
        string[] storage userPendingTransfers = pendingTransfers[user];
        for (uint i = 0; i < userPendingTransfers.length; i++) {
            if (keccak256(bytes(userPendingTransfers[i])) == keccak256(bytes(serialNo))) {
                userPendingTransfers[i] = userPendingTransfers[userPendingTransfers.length - 1];
                userPendingTransfers.pop();
                break;
            }
        }
    }

    function getProductDetails(string memory serialNo) public view returns (Product memory) {
        return products[serialNo];
    }

    function getEntityDetails(address _entity) public view returns (Entity memory) {
        return entities[_entity];
    }

    // New function to get all registered entity addresses
    function getAllRegisteredEntities() public view returns (address[] memory) {
        return registeredEntities;
    }

    // New function to get all product serial numbers
    function getAllProductSerialNumbers() public view returns (string[] memory) {
        return productSerialNumbers;
    }
}
