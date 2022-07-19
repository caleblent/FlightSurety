pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;    // Account used to deploy contract
    bool private operational = true;  // Blocks all state changes throughout the contract if false

    struct Airline {
        bool isRegistered;
        bool isOperational;
    }

    struct Insurance {
        address passenger;
        uint256 amount;
    }

    struct Fund {
        uint256 amount;
    }

    struct Vote {
        bool status;
    }

    mapping (address => Airline) airlines;
    mapping (address => Insurance) insurances;
    mapping (address => Fund) funds;
    mapping (address => Vote) votes;

    mapping (address => uint) private voteCount;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


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




   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (   
                                address account,
                                bool isOperational
                            )
                            external
                            requireIsOperational
    {
        // passes data to the private function, which handles it
        _registerAirline(account, isOperational);
    }

    // handles the airline registration
    function _registerAirline (address account, bool isOperational) private {
        airlines[account] = Airline({
            isRegistered: true,
            isOperational: isOperational
        });
    }

    function isAirline (address account) external view returns (bool) {
        require(account != address(0), "'account' must be a valid address");
        return airlines[account].isRegistered;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (                             
                            )
                            external
                            payable
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
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
    function() 
                            external 
                            payable 
    {
        fund();
    }


}

