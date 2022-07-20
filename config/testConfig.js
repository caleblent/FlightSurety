
var FlightSuretyApp = artifacts.require("FlightSuretyApp");
var FlightSuretyData = artifacts.require("FlightSuretyData");
var BigNumber = require('bignumber.js');

var Config = async function(accounts) {
    
    // These test addresses are useful when you need to add
    // multiple users in test scripts
    let testAddresses = [
        "0x69e1CB5cFcA8A311586e3406ed0301C06fb839a2",
        "0xF014343BDFFbED8660A9d8721deC985126f189F3",
        "0x0E79EDbD6A727CfeE09A2b1d0A59F7752d5bf7C9",
        "0x9bC1169Ca09555bf2721A5C9eC6D69c8073bfeB4",
        "0xa23eAEf02F9E0338EEcDa8Fdd0A73aDD781b2A86",
        "0x6b85cc8f612d5457d49775439335f83e12b8cfde",
        "0xcbd22ff1ded1423fbc24a7af2148745878800024",
        "0xc257274276a4e539741ca11b590b9447b26a8051",
        "0x2f2899d6d35b1a48a4fbdc93a37a72f264a9fca7",
        "0xEeDa64a0F6173a4f339B2Bd11BA3511e130A6946"
    ];

    // let testAddresses = [
    //     "0xFbCad7d9FFa3b7b6381624Af8640b47c71C417Bf",
    //     "0x53700168D24d156ced40818330eA112D26554204",
    //     "0xEE54011C09ccf5Dc5F03aF58A900951A4c8f58Bc",
    //     "0xf1132eaf99dbe86BFb7C7fcaFdf5d9b3C2517E55",
    //     "0xA3E8235Cba5D16Cae013CD22e988a58DF71F7218",
    //     "0x7de1Be2e2beb74eB1d9D9Cbf960D6d6A7932dE38",
    //     "0x7649DFEd51555bAd23E44cC38CD4D9e11a9A7c01",
    //     "0x38972710206e337777dF17712720171E2b632204",
    //     "0x7434268773771beBA50382c0aa38bf7a556FDEcA",
    //     "0xEeDa64a0F6173a4f339B2Bd11BA3511e130A6946"
    // ];

    let owner = accounts[0];
    let firstAirline = accounts[1];

    let flightSuretyData = await FlightSuretyData.new();
    let flightSuretyApp = await FlightSuretyApp.new();

    
    return {
        owner: owner,
        firstAirline: firstAirline,
        weiMultiple: (new BigNumber(10)).pow(18),
        testAddresses: testAddresses,
        flightSuretyData: flightSuretyData,
        flightSuretyApp: flightSuretyApp
    }
}

module.exports = {
    Config: Config
};