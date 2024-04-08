// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProvenance {
    // Function to get details of an entity, now includes the entity's location.
    function getEntityDetails(address _entity) external view returns (Role, string memory, string memory, bool, bool);
    // Function to get all registered entities, remains unchanged.
    function getAllRegisteredEntities() external view returns (address[] memory);
    // New function to get the source products of a given product.
    function getSourceProducts(string memory serialNo) external view returns (string[] memory);
}

contract SupplyChainTracking {
    address public admin;
    IProvenance public provenanceContract;
    mapping(string => Shipment) public shipments;
    string[] public shipmentSerialNumbers;

    // Role enumeration, matching the one in the Provenance contract.
    enum Role { Supplier, Producer, Transporter, Warehouse, Market }
    enum ShipmentStatus { Created, InTransit, Delivered, Rejected }

    // Event declarations for various actions within the contract.
    event ShipmentAdded(string serialNo, string item, uint quantity, uint timeStamp, address indexed sender, string[] sourceProductSerialNos);
    event ShipmentStatusUpdated(string serialNo, ShipmentStatus status, uint timeStamp);
    event TemperatureLogged(string serialNo, int temperature, uint timeStamp);
    event Alert(string serialNo, string message, uint timeStamp);

    struct Shipment {
        string item;
        uint quantity;
        uint timeStamp;
        ShipmentStatus status;
        address currentHolder;
        int[] temperatures; // Array to store temperature readings.
        string[] sourceProductSerialNos; // Array to store source product serial numbers.
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    constructor(address _provenanceContract) {
        admin = msg.sender;
        provenanceContract = IProvenance(_provenanceContract);
    }

    function addShipment(string memory serialNo, string memory _item, uint _quantity, string[] memory _sourceProductSerialNos) public {
        (Role senderRole,, bool isRegistered,) = provenanceContract.getEntityDetails(msg.sender);
        require(isRegistered, "Sender must be a registered entity");
        require(bytes(serialNo).length != 0, "Serial number cannot be empty");
        require(shipments[serialNo].timeStamp == 0, "Shipment already exists");

        // Verify the existence of each source product.
        for (uint i = 0; i < _sourceProductSerialNos.length; i++) {
            require(provenanceContract.getSourceProducts(_sourceProductSerialNos[i]).length > 0, "One or more source products do not exist");
        }

        shipments[serialNo] = Shipment(_item, _quantity, block.timestamp, ShipmentStatus.Created, msg.sender, new int[](0), _sourceProductSerialNos);
        shipmentSerialNumbers.push(serialNo);
        emit ShipmentAdded(serialNo, _item, _quantity, block.timestamp, msg.sender, _sourceProductSerialNos);
    }

    function updateShipmentStatus(string memory serialNo, ShipmentStatus _status) public {
        require(shipments[serialNo].currentHolder == msg.sender, "Only the current holder can update status");
        shipments[serialNo].status = _status;
        emit ShipmentStatusUpdated(serialNo, _status, block.timestamp);
    }

    function logTemperature(string memory serialNo, int _temperature) public {
        require(shipments[serialNo].currentHolder == msg.sender, "Only the current holder can log temperature");
        shipments[serialNo].temperatures.push(_temperature);
        emit TemperatureLogged(serialNo, _temperature, block.timestamp);
    }

    function createAlert(string memory serialNo, string memory _message) public {
        require(shipments[serialNo].currentHolder == msg.sender, "Only the current holder can create an alert for the shipment");
        emit Alert(serialNo, _message, block.timestamp);
    }

    function getShipmentDetails(string memory serialNo) public view returns (Shipment memory) {
        return shipments[serialNo];
    }

    function getAllShipmentSerialNumbers() public view returns (string[] memory) {
        return shipmentSerialNumbers;
    }

    // Utilizing Provenance contract's function to fetch all registered entities.
    function getAllRegisteredEntities() public view returns (address[] memory) {
        return provenanceContract.getAllRegisteredEntities();
    }

    // New function to get the source products of a shipment item.
    function getShipmentItemSourceProducts(string memory serialNo) public view returns (string[] memory) {
        require(shipments[serialNo].timeStamp != 0, "Shipment does not exist");
        return shipments[serialNo].sourceProductSerialNos;
    }
}
