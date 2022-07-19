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
    using SafeMath for uint8; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    // Object that we will use to interact with the FlightSuretyApp contract.
    FlightSuretyData flightSuretyData; 

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    uint constant M = 4;
    bool private vote_status = false;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    bool private operational = true;        // Can be set to false to pause contract operations

    struct Flight {
        bool isRegistered;
        // uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }

    mapping(bytes32 => Flight) private flights;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event RegisteredAirline(address account);
    event FundedLines(address account, uint256 amount);
    event PurchasedInsurance(address airline, address account, uint256 amount);
    event Withdrew(address account , uint256 amount);
    event CreditedInsurees(address airline, address passenger, uint256 credit);


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
    modifier requireAirlineIsRegistered(address airline)
    {
        require(flightSuretyData.getAirlineRegistrationStatus(airline), "Airline is not registered");
        _;
    }
    modifier requireAirlineIsNotRegistered(address airline)
    {
        require(!flightSuretyData.getAirlineRegistrationStatus(airline), "Airline is already registered");
        _;
    }
    modifier requireAirlineIsOperational(address airline)
    {
        require(flightSuretyData.getAirlineOperatingStatus(airline), "Airline is not operational");
        _;
    }
    // modifier requireAirlineIsNotOperational(address airline)
    // {
    //     require(!flightSuretyData.getAirlineOperatingStatus(airline), "Airline is already operational");
    //     _;
    // }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address dataContract
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
        flightSuretyData.registerAirline(contractOwner, true);
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
    */   
    function registerAirline(address airline) 
        external 
        requireIsOperational 
        requireAirlineIsNotRegistered(airline)
        requireAirlineIsOperational(airline)
        returns(bool, bool)
    {
        require(airline != address(0), "'account' must be a valid address.");

        uint multiCallLength = flightSuretyData.multiCallsLength();

        if (multiCallLength < M) {
            // Register airline directly
            flightSuretyData.registerAirline(airline, false);
            emit RegisteredAirline(airline);
            return(true, false); // registered without a vote
        } else {
            if (vote_status){
                uint voteCount = flightSuretyData.getVoteCounter(airline);

                if(voteCount >= multiCallLength.div(2)){
                    // Airline has been voted in
                    flightSuretyData.registerAirline(airline, false);
  
                    vote_status = false;
                    flightSuretyData.resetVoteCounter(airline);

                    emit RegisteredAirline(airline);
                    return(true, true);             

                } else {
                    // Airline has been voted out
                    flightSuretyData.resetVoteCounter(airline);
                    return(false, true); 
                }
            } else {
                // Requesting for a vote
                return(false,false);                 
            }
        }
    }

    /**
    * @dev Approve registration of fifth and subsequent airlines
    *
    */

    function approveAirlineRegistration(address airline, bool airline_vote) public requireIsOperational {
        
        require(!flightSuretyData.getAirlineRegistrationStatus(airline),"airline already registered");
        require(flightSuretyData.getAirlineOperatingStatus(msg.sender),"airline not operational");
        
        if(airline_vote == true){
            // Check and avoid duplicate vote for the same airline
            bool isDuplicate = false;
            uint incrementVote = 1;
            isDuplicate = flightSuretyData.getVoterStatus(msg.sender);

            // Check to avoid registering same airline multiple times
            require(!isDuplicate, "Caller has already voted.");
            flightSuretyData.addVoters(msg.sender);
            flightSuretyData.addVoterCounter(airline, incrementVote);

            }
        vote_status = true;
    }

    /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */ 

    function fund
                (
                )
                public
                payable
                requireIsOperational
    {
        // vreify fund is 10 ether
        require(msg.value == 10 ether,"Ether should be 10");

        // Make sure airline has not yet been funded
        require(!flightSuretyData.getAirlineOperatingStatus(msg.sender), "Airline is already funded");

        // Save in contract instead
        //contractOwner.transfer(msg.value); 

        flightSuretyData.fundAirline(msg.sender, msg.value);

        flightSuretyData.setAirlineOperatingStatus(msg.sender, true);

        emit FundedLines(msg.sender, msg.value);
        
    }

    /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (
                                address airline
                                
                            )
                            external
                            payable
                            requireIsOperational
    {
        // Check if airline is operational
        require(flightSuretyData.getAirlineOperatingStatus(airline),"Airline you are buying insurance from should be operational");
        
        // Check if amount range is greater than 0 ether and less than 1 ether.
        require((msg.value > 0 ether) && (msg.value <= 1 ether), "You can not buy insurance of more than 1 ether or less than 0 ether");

        // Save in contract instead
        //airline.transfer(msg.value);
        // Register insurance in database
        flightSuretyData.registerInsurance(airline, msg.sender, msg.value);

        //uint256 getFund = flightSuretyData.getAirlineFunding(airline);

        emit PurchasedInsurance(airline, msg.sender, msg.value);

    }

    // Getter function for passenger credited amount
    function getPassengerCreditedAmount() external returns(uint256) {
        return flightSuretyData.getPassengerCredit(msg.sender);
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function withdraw
                            (
                            )
                            external
                            requireIsOperational
                            
    {
        require(flightSuretyData.getPassengerCredit(msg.sender) > 0, "No balance to withdraw");

        uint256 withdrawalValue = flightSuretyData.withdraw(msg.sender);
        // Transfer credit to passenger wallet
        msg.sender.transfer(withdrawalValue);
        
        emit Withdrew(msg.sender, withdrawalValue);
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
                                (
                                )
                                external
                                requireIsOperational
    {

    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    address airline,
                                    string  flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                public
                                
                             
    {
        address passenger;
        uint256 amountPaid;
        (passenger,amountPaid) = flightSuretyData.getInsuredPassengerAmount(airline);

        require((passenger != address(0)) && (airline != address(0)), "'accounts' must be  valid address.");
        require(amountPaid > 0, "Passenger is not insured");

        // Only credit if flight delay is airline fault (airline late and late due to technical)
        if((statusCode == STATUS_CODE_LATE_AIRLINE) || (statusCode == STATUS_CODE_LATE_TECHNICAL)){
            uint256 credit = amountPaid.mul(3).div(2);

            flightSuretyData.creditInsurees(airline, passenger, credit);
            emit CreditedInsurees(airline, passenger, credit);
        }
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp                            
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
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
