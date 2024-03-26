// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProvenance {
    function getEntityDetails(address _entity) external view returns (Role, string memory, bool, bool);
    function getAllRegisteredEntities() external view returns (address[] memory);
}

contract SupplyChainTracking {
    address public admin;
    IProvenance public provenanceContract;
    mapping(string => Shipment) public shipments;
    string[] public shipmentSerialNumbers;

    enum Role { Supplier, Producer, Transporter, Warehouse, Market }
    enum ShipmentStatus { Created, InTransit, Delivered, Rejected }

    event ShipmentAdded(string serialNo, string item, uint quantity, uint timeStamp, address indexed sender);
    event ShipmentStatusUpdated(string serialNo, ShipmentStatus status, uint timeStamp);
    event TemperatureLogged(string serialNo, int temperature, uint timeStamp);
    event Alert(string serialNo, string message, uint timeStamp);

    struct Shipment {
        string item;
        uint quantity;
        uint timeStamp;
        ShipmentStatus status;
        address currentHolder;
        int[] temperatures; // Array to store temperature readings
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    constructor(address _provenanceContract) {
        admin = msg.sender;
        provenanceContract = IProvenance(_provenanceContract);
    }

    function addShipment(string memory serialNo, string memory _item, uint _quantity) public {
        (Role senderRole,, bool isRegistered,) = provenanceContract.getEntityDetails(msg.sender);
        require(isRegistered, "Sender must be a registered entity");
        require(bytes(serialNo).length != 0, "Serial number cannot be empty");
        require(shipments[serialNo].timeStamp == 0, "Shipment already exists");

        shipments[serialNo] = Shipment(_item, _quantity, block.timestamp, ShipmentStatus.Created, msg.sender, new int[](0));
        shipmentSerialNumbers.push(serialNo);
        emit ShipmentAdded(serialNo, _item, _quantity, block.timestamp, msg.sender);
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

    function getAllRegisteredEntities() public view returns (address[] memory) {
        return provenanceContract.getAllRegisteredEntities();
    }
}
