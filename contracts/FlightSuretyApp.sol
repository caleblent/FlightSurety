pragma solidity ^0.4.24;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

// Also must import the FlightSuretyData contract
// NOTE: Another option is to use an interface, but I have opted for an import instead

import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)
    using SafeMath for uint8; // Allow SafeMath functions to be called for all uint8 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    // Insurace Constants
    uint256 AIRLINE_REGISTRATION_FEE = 10 ether;
    uint256 MAX_INSURANCE_PLAN = 1 ether;
    uint256 INSURANCE_PAYOUT = 150; // Must divide by 100 to get percentage payout

    // Airline Registration Helpers
    uint256 AIRLINE_VOTING_THRESHOLD = 4;
    uint256 AIRLINE_REGISTRATION_REQUIRED_VOTES = 2;

    // Account used to deploy contract
    address private contractOwner;

    // Can be set to false to pause contract operations
    bool private operational = true;

    // Airlines
    struct PendingAirline {
        bool isRegistered;
        bool isFunded;
    }

    mapping(address => address[]) public pendingAirlines;

    // Object that we will use to interact with the FlightSuretyApp contract.
    FlightSuretyData flightSuretyData; 

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address data) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(data);
    }

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    // event RegisteredAirline(address account);
    // event FundedLines(address account, uint256 amount);
    // event PurchasedInsurance(address airline, address account, uint256 amount);
    // event Withdrew(address account , uint256 amount);
    // event CreditedInsurees(address airline, address passenger, uint256 credit);
    // event RegisteredFlight(bytes32 flightKey, address airline);
    // event ProcessedFlightStatus(bytes32 flightKey, uint8 statusCode);


    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
         // Calls data contract's status
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

    // self explanatory modifiers
    modifier requireAirlineIsRegistered(address airline) {
        require(flightSuretyData.isAirlineRegistered(airline), "Airline is not registered");
        _;
    }
    modifier requireAirlineIsNotRegistered(address airline) {
        require(!flightSuretyData.isAirlineRegistered(airline), "Airline is already registered");
        _;
    }
    modifier requireAirlineIsFunded(address airline) {
        require(flightSuretyData.isAirlineFunded(airline), "Airline is not funded.");
        _;
    }
    modifier requireAirlineIsNotFunded(address airline) {
        require(!flightSuretyData.isAirlineFunded(airline), "Airline is already funded.");
        _;
    }
    modifier requireSufficientFunding(uint256 amount) {
        require(msg.value >= amount, "Insufficient Funds.");
        _;
    }
    modifier calculateRefund() {
        _;
        uint refund = msg.value - AIRLINE_REGISTRATION_FEE;
        msg.sender.transfer(refund);
    }
    modifier requireFlightIsRegistered(bytes32 flightKey) {
        require(flightSuretyData.isFlightRegistered(flightKey), "Flight is not registered.");
        _;
    }
    modifier requireFlightIsNotLanded(bytes32 flightKey) {
        require(!flightSuretyData.isFlightLanded(flightKey), "Flight has already landed");
        _;
    }
    modifier requirePassengerNotInsuredForFlight(bytes32 flightKey, address passenger) {
        require(!flightSuretyData.isPassengerInsuredForFlight(flightKey, passenger), "Passenger is already insured for flight");
        _;
    }
    modifier requireLessThanMaxInsurance() {
        require(msg.value <= MAX_INSURANCE_PLAN, "Value exceeds max insurance plan.");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    // the getter function essentially
    function isOperational()
                            public 
                            view 
                            returns(bool) 
    {
        return operational;  // Modify to call data contract's status
    }

    function setOperationalStatus(bool status)
                            external
                            requireContractOwner
    {
        operational = status;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    * @return Success/Failure, Votes cast for airline, current member count
    */
    function registerAirline(address airline)
        external
        requireIsOperational
        requireAirlineIsNotRegistered(airline) // Airline is not registered yet
        requireAirlineIsFunded(msg.sender) // Voter is a funded airline
        returns(bool success, uint256 votes, uint256 registeredAirlineCount)
    {
        // If less than required minimum airlines for voting process
        if (flightSuretyData.getRegisteredAirlineCount() <= AIRLINE_VOTING_THRESHOLD) {
            // sends data to FlightSuretyData contract to be processed
            flightSuretyData.registerAirline(airline);
            return(success, 0, flightSuretyData.getRegisteredAirlineCount());
        } else {
            // Check for duplicates
            bool isDuplicate = false;
            for (uint256 i = 0; i < pendingAirlines[airline].length; i++) {
                if (pendingAirlines[airline][i] == msg.sender) {
                    isDuplicate = true;
                    break;
                }
            }
            require(!isDuplicate, "Duplicate vote, you cannot vote for the same airline twice.");
            pendingAirlines[airline].push(msg.sender);
            // Check if enough votes to register airline
            if (pendingAirlines[airline].length >= flightSuretyData.getRegisteredAirlineCount().div(AIRLINE_REGISTRATION_REQUIRED_VOTES)) {
                // sends data to FlightSuretyData contract to be processed
                flightSuretyData.registerAirline(airline);
                return(true, pendingAirlines[airline].length, flightSuretyData.getRegisteredAirlineCount());
            }
            return(false, pendingAirlines[airline].length, flightSuretyData.getRegisteredAirlineCount());
        }
    }

    /**
     * @dev Fund a registered airline
     */
    function fundAirline()
        external
        payable
        requireIsOperational
        requireAirlineIsRegistered(msg.sender)
        requireAirlineIsNotFunded(msg.sender)
        requireSufficientFunding(AIRLINE_REGISTRATION_FEE)
        returns(bool)
    {
        address(uint160(address(flightSuretyData))).transfer(AIRLINE_REGISTRATION_FEE);
        
        // sends data to FlightSuretyData contract to be processed
        return flightSuretyData.fundAirline(msg.sender, AIRLINE_REGISTRATION_FEE);
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight (string flightNumber, uint256 timestamp, string departureLocation, string arrivalLocation)
        external
        requireIsOperational
        requireAirlineIsFunded(msg.sender)
    {
        bytes32 flightKey = getFlightKey(msg.sender, flightNumber, timestamp);

        
        // sends data to FlightSuretyData contract to be processed
        flightSuretyData.registerFlight(
            flightKey,
            timestamp,
            msg.sender,
            flightNumber,
            departureLocation,
            arrivalLocation
        );
    }

    /**
    * @dev Called after oracle has updated flight status
    *
    */
    function processFlightStatus(address airline, string flight, uint256 timestamp, uint8 statusCode)
        internal
        requireIsOperational
    {
        // sends data to FlightSuretyData contract to be processed
        flightSuretyData.processFlightStatus(airline, flight, timestamp, statusCode);
    }

    /**
    * @dev Generate a request for oracles to fetch flight information
    *
    */  
    function fetchFlightStatus (address airline, string flight, uint256 timestamp, bytes32 flightKey)
        external
        requireFlightIsRegistered(flightKey)
        requireFlightIsNotLanded(flightKey)
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({requester: msg.sender, isOpen: true});

        emit OracleRequest(index, airline, flight, timestamp);
    }

    function buyInsurance (bytes32 flightKey)
        public
        payable
        requireIsOperational
        requireFlightIsRegistered(flightKey)
        requireFlightIsNotLanded(flightKey)
        requirePassengerNotInsuredForFlight(flightKey, msg.sender)
        requireLessThanMaxInsurance()
    {
        // sends data to FlightSuretyData contract to be processed
        address(uint160(address(flightSuretyData))).transfer(msg.value);
        flightSuretyData.buyInsurance(flightKey, msg.sender, msg.value, INSURANCE_PAYOUT);
    }

    function pay() external requireIsOperational {
        // sends data to FlightSuretyData contract to be processed
        flightSuretyData.pay(msg.sender);
    }

// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 2;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   

// Interface to FlightSuretyData.sol
// NOTE: I have imported the FlightSuretyData.sol contract so this is not needed
// contract FlightSuretyData{
//     function registerAirline(address account, bool isOperational) external;
//     function multiCallsLength() external returns(uint);
//     function getAirlineOperatingStatus(address account) external returns(bool);
//     function setAirlineOperatingStatus(address account, bool status) external;
//     function registerInsurance(address airline, address passenger, uint256 amount) external;
//     function creditInsurees(address airline, address passenger, uint256 amount) external;
//     function getInsuredPassengerAmount(address airline) external returns(address, uint256);
//     function getPassengerCredit(address passenger) external returns(uint256);
//     function getAirlineRegistrationStatus(address account) external  returns(bool);
//     function fundAirline(address airline, uint256 amount) external;
//     function getAirlineFunding(address airline) external returns(uint256);
//     function withdraw(address passenger) external returns(uint256);
//     function getVoteCounter(address account) external  returns(uint);
//     function setVoteCounter(address account, uint vote) external;
//     function getVoterStatus(address voter) external returns(bool);
//     function addVoterCounter(address airline, uint count) external;
//     function resetVoteCounter(address account) external;
//     function addVoters(address voter) external;
// }   
