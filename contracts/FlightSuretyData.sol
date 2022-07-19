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
        bool isOperational;
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

    // struct Fund {
    //     uint256 amount;
    //     string currency; // will be set to "ETH" by default, but it allows us to change it if so desired
    // }

    // struct Vote {
    //     bool status;
    // }

    // mapping (address => Airline) airlines;
    // mapping (address => Insurance) insurances;
    // mapping (address => Fund) funds;
    // mapping (address => Vote) votes;

    // mapping (address => uint) private voteCount;
    // mapping (address => uint256) private authorizedCaller;
    // mapping (address => uint256) balances;
    // address[] multiCalls = new address[](0);

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor (address airline) public 
    {
        contractOwner = msg.sender;
        airlines[airline] = Airline(true, true, false, 0);
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

    // Setter and Getter functions for data structures

    // Airline struct
    function getAirlineOperatingStatus(address account) external view requireIsOperational returns (bool) {
        return airlines[account].isOperational;
    }
    function setAirlineOperatingStatus(address account, bool status) external requireIsOperational {
        airlines[account].isOperational = status;
    }
    function getAirlineRegistrationStatus(address account) external view requireIsOperational returns (bool) {
        return airlines[account].isRegistered;
    }
    // function setAirlineRegistrationStatus(address account, bool status) external requireIsOperational {
    //     airlines[account].isRegistered = status;
    // }

    // Vote struct
    function getVoteCounter(address account) external view requireIsOperational returns (uint) {
        return voteCount[account];
    }
    function resetVoteCounter(address account) external requireIsOperational {
        delete voteCount[account];
    }
    function getVoterStatus(address voter) external view requireIsOperational returns (bool) {
        return votes[voter].status;
    }
    function addVoters(address voter) external {
        votes[voter] = Vote({
            status: true
        });
    }
    function addVoterCounter(address airline, uint count) external {
        uint vote = voteCount[airline];
        voteCount[airline] = vote.add(count);
    }

    // multiCalls
    function setMultiCalls(address account) private {
        multiCalls.push(account);
    }
    function multiCallsLength() external view requireIsOperational returns(uint) {
        return multiCalls.length;
    }

    // Insurance Registration
    function registerInsurance(address airline, address passenger, uint256 amount) external requireIsOperational {
        insurances[airline] = Insurance({
            passenger: passenger,
            amount: amount
        });
        uint256 getFund = funds[airline].amount;
        funds[airline].amount = getFund.add(amount);
    }

    // Fund Recording
    function fundAirline(address airline, uint256 amount) external {
        funds[airline] = Fund({
            amount: amount,
            currency: "ETH"
        });
    }

    function getAirlineFunding(address airline) external view returns(uint256) {
        return funds[airline].amount;
    }

    // Functions that deal with authorization + the contract caller
    function authorizeCaller(address contractAddress) external requireContractOwner {
        authorizedCaller[contractAddress] = 1;
        emit AuthorizedContract(contractAddress);
    }

    function deauthorizeContract(address contractAddress) external requireContractOwner {
        delete authorizedCaller[contractAddress];
        emit DeAuthorizedContract(contractAddress);
    }

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline (address account, bool _isOperational) external requireIsOperational {
        airlines[account] = Airline({
            isRegistered: true,
            isOperational: _isOperational
        });

        setMultiCalls(account);
    }

    function isAirline (address account) external view returns (bool) {
        require(account != address(0), "'account' must be a valid address");
        return airlines[account].isRegistered;
    }

    // Insurance payout functions

   /**
    * @dev Buy insurance for a flight
    *
    */   
    // function buy
    //                         (                             
    //                         )
    //                         external
    //                         payable
    // {

    // }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsuree
                                (
                                    address airline,
                                    address passenger,
                                    uint256 amount
                                )
                                external
                                requireIsOperational
    {
        // gets the amount * 3 / 2 ... same as 1.5x the amount
        uint256 requiredAmount = insurances[airline].amount.mul(3).div(2);

        require(insurances[airline].passenger == passenger, "Passenger is not insured");
        require(requiredAmount == amount, "The amount credited is not as expected");
        require((passenger != address(0)) && (airline != address(0)), "'accounts' must be a valid address");

        balances[passenger] = amount;
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function withdraw(address passenger) external payable requireIsOperational
    returns (uint256) {
        // stores the payout amount in withdrawalAmount
        uint256 withdrawalAmount = balances[passenger];

        // checks to see if funds are available
        require(address(this).balance >= withdrawalAmount, "Contract has insufficient funds.");
        require(withdrawalAmount > 0, "There are no funds available for withdrawal");

        // removes entry from balances
        delete balances[passenger];

        // pays the passenger
        passenger.transfer(withdrawalAmount);

        emit PaidInsuree(passenger, withdrawalAmount);
        return withdrawalAmount;
    }

    function getInsuredPassengerAmount(address airline) external view requireIsOperational 
    returns(address, uint256) {
        return (insurances[airline].passenger, insurances[airline].amount);
    }

    function getPassengerCredit(address passenger) external view requireIsOperational
    returns(uint256) {
        return balances[passenger];
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
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
    {
    }
    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }


}

