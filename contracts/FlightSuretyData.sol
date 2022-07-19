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
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable {}
    
}

