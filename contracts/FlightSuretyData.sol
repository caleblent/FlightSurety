pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;    // Account used to deploy contract
    bool private operational = true;  // Blocks all state changes throughout the contract if false

    // Airline variables
    struct Airline {
        bool isRegistered;
        bool isFunded;
        uint256 funds;
    }
    uint256 registeredAirlineCount = 0;
    uint256 fundedAirlineCount = 0;
    mapping(address => Airline) private airlines;

    // Flight variables
    struct Flight {
        bool isRegistered;
        bytes32 flightKey;
        address airline;
        string flightNumber;
        uint8 statusCode;
        uint256 timestamp;
        string departureLocation;
        string arrivalLocation;
    }
    mapping(bytes32 => Flight) public flights;
    bytes32[] public registeredFlights;

    // Insurance variables
    struct InsuranceClaim {
        address passenger;
        uint256 purchasePrice;
        uint256 payoutPercentage;
        bool credited;
    }
    mapping(bytes32 => InsuranceClaim[]) public flightInsuranceClaims; // Flight insurance claims
    mapping(address => uint256) public withdrawableFunds; // Passenger insurance claims

    mapping(address => uint256) private authorizedCaller;

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor () public 
    {
        contractOwner = msg.sender;
    }

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(address airline);
    event AirlineFunded(address airline);
    event FlightRegistered(bytes32 flightKey);
    event ProcessedFlightStatus(bytes32 flightKey, uint8 statusCode);
    event PassengerInsured(bytes32 flightKey, address passenger, uint256 amount, uint256 payout);
    event InsureeCredited(bytes32 flightKey, address passenger, uint256 amount);
    event PaidInsuree(address payoutAddress, uint256 amount);
    event AuthorizedContract(address authContract);
    event DeAuthorizedContract(address authContract);

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    // Airline Registration
    modifier requireAirlineIsRegistered(address airline)
    {
        require(airlines[airline].isRegistered, "Airline is not registered");
        _;
    }
    modifier requireAirlineIsNotRegistered(address airline)
    {
        require(!airlines[airline].isRegistered, "Airline is already registered");
        _;
    }

    // Airline Funding
    modifier requireAirlineIsFunded(address airline)
    {
        require(airlines[airline].isFunded, "Airline is not funded");
        _;
    }
    modifier requireAirlineIsNotFunded(address airline)
    {
        require(!airlines[airline].isFunded, "Airline is already funded");
        _;
    }

    // Flight Registration
    modifier requireFlightIsRegistered(bytes32 flightKey) {
        require(flights[flightKey].isRegistered, "Flight is not registered");
        _;
    }
    modifier requireFlightIsNotRegistered(bytes32 flightKey) {
        require(!flights[flightKey].isRegistered, "Flight is already registered");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    // Getter/Setter functions
    function isAirlineRegistered(address airline) public view requireIsOperational returns(bool) {
        return airlines[airline].isRegistered;
    }
    function isAirlineFunded(address airline) public view returns(bool) {
        return airlines[airline].isFunded;
    }
    function isFlightRegistered(bytes32 flightKey) public view returns(bool) {
        return flights[flightKey].isRegistered;
    }
    function isFlightLanded(bytes32 flightKey) public view returns(bool) {
        if (flights[flightKey].statusCode > 0) {
            return true;
        }
        return false;
    }
    function isPassengerInsuredForFlight(bytes32 flightKey, address passenger) public view returns(bool) {
        InsuranceClaim[] memory insuranceClaims = flightInsuranceClaims[flightKey];
        for (uint256 i = 0; i < insuranceClaims.length; i++) {
            if (insuranceClaims[i].passenger == passenger) {
                return true;
            }
        }
        return false;
    }

    // Other useful functions
    function isAirline (address account) external view returns (bool) {
        require(account != address(0), "'account' must be a valid address");
        return airlines[account].isRegistered;
    }
    function getRegisteredAirlineCount() public view requireIsOperational returns(uint256) {
        return registeredAirlineCount;
    }
    function getFundedAirlineCount() public view requireIsOperational returns(uint256) {
        return fundedAirlineCount;
    }
    function getCountRegisteredFlights() public view requireIsOperational returns(uint256) {
        return registeredFlights.length;
    }
    function getFlightKey(address airline, string memory flight, uint256 timestamp) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }


    // Main meat and potatoes functions

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline (address airline) 
        external 
        requireIsOperational
        requireAirlineIsNotRegistered(airline)
        requireAirlineIsFunded(airline)
    {
        airlines[airline] = Airline(true, false, 0);
        registeredAirlineCount = registeredAirlineCount.add(1);
        emit AirlineRegistered(airline);
    }

    /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    */
    function fundAirline(address airline, uint256 amount)
        external
        requireIsOperational
        requireAirlineIsRegistered(airline)
        requireAirlineIsNotFunded(airline)
        returns(bool)
    {
        airlines[airline].isFunded = true;
        airlines[airline].funds = airlines[airline].funds.add(amount);
        fundedAirlineCount = fundedAirlineCount.add(1);
        emit AirlineFunded(airline);
        return airlines[airline].isFunded;
    }

    function registerFlight (bytes32 flightKey, uint256 timestamp, address airline, string memory flightNumber, 
    string memory departureLocation, string memory arrivalLocation)
        public
        payable
        requireIsOperational
        requireAirlineIsFunded(airline)
        requireFlightIsNotRegistered(flightKey)
    {
        flights[flightKey] = Flight(
            true,
            flightKey,
            airline,
            flightNumber,
            0,
            timestamp,
            departureLocation,
            arrivalLocation
        );
        registeredFlights.push(flightKey);
        emit FlightRegistered(flightKey);
    }

    function processFlightStatus(address airline, string flight, uint256 timestamp, uint8 statusCode) external requireIsOperational {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        require(!isFlightLanded(flightKey), "Flight has already landed.");
        if (flights[flightKey].statusCode == 0) {
            flights[flightKey].statusCode = statusCode;
            if (statusCode == 20) {
                creditInsurees(flightKey);
            }
        }
        emit ProcessedFlightStatus(flightKey, statusCode);
    }

    /**
    * @dev Buy insurance for a flight
    */
    function buyInsurance (bytes32 flightKey, address passenger, uint256 amount, uint256 payout)
        external
        payable
        requireIsOperational
    {
        require(isFlightRegistered(flightKey), "Flight is already registered");
        require(!isFlightLanded(flightKey), "Flight has already landed");

        flightInsuranceClaims[flightKey].push(InsuranceClaim(
            passenger,
            amount,
            payout,
            false
        ));
        emit PassengerInsured(flightKey, passenger, amount, payout);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(bytes32 flightKey) internal requireIsOperational {
        for (uint256 i = 0; i < flightInsuranceClaims[flightKey].length; i++) {
            InsuranceClaim memory insuranceClaim = flightInsuranceClaims[flightKey][i];
            insuranceClaim.credited = true;
            uint256 amount = insuranceClaim.purchasePrice.mul(insuranceClaim.payoutPercentage).div(100);
            withdrawableFunds[insuranceClaim.passenger] = withdrawableFunds[insuranceClaim.passenger].add(amount);
            emit InsureeCredited(flightKey, insuranceClaim.passenger, amount);
        }
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
    */
    function pay(address payoutAddress) external payable requireIsOperational {
        uint256 amount = withdrawableFunds[payoutAddress];
        require(address(this).balance >= amount, "Contract has insufficient funds.");
        require(amount > 0, "There are no funds available for withdrawal");
        withdrawableFunds[payoutAddress] = 0;
        address(uint160(address(payoutAddress))).transfer(amount);
        emit PaidInsuree(payoutAddress, amount);
    }

    // Authorize / Deauthorize Caller functions
    function authorizeCaller(address contractAddress) external requireContractOwner {
        authorizedCaller[contractAddress] = 1;
        emit AuthorizedContract(contractAddress);
    }

    function deauthorizeContract(address contractAddress) external requireContractOwner {
        delete authorizedCaller[contractAddress];
        emit DeAuthorizedContract(contractAddress);
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable {}

}

