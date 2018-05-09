pragma solidity ^0.4.18;

import "../zeppelin/ownership/Ownable.sol";
import "../interfaces/I_Oracle.sol";


/**
 * @title Base contract for mocked oracles for testing in private nodes.
 *
 * @dev Base contract for oracles. Not abstract.
 */
contract BountyOracleBase is Ownable {

    bytes32 public oracleName = "Bounty Oracle";
    bytes16 public oracleType = "Bounty";
    mapping (address => uint256) private rates;
    uint256 public mockRate = 280000;
    event PriceTicker(address bank, uint price);

    mapping (address => uint256) private updateTimes;
    mapping (address => uint256) private callbackTimes;
    mapping (address => bool) private waitQuerys;
    uint256 constant MOCK_REQUEST_PRICE = 1000;
    mapping (address => uint256) private prices;
    
    /**
     * @dev waitQuery getter for msg.sender.
     */
    function waitQuery() public view returns (bool) {
        return waitQuerys[msg.sender];
    }

    /**
     * @dev Price getter for msg.sender.
     */
    function price() public view returns (uint256) {
        return prices[msg.sender];
    }
    
    /**
     * @dev Rate getter for msg.sender.
     */
    function rate() public view returns (uint256) {
        return rates[msg.sender];
    }
    
    /**
     * @dev updateTime getter for msg.sender.
     */
    function updateTime() public view returns (uint256) {
        return updateTimes[msg.sender];
    }
    
    /**
     * @dev callbackTime getter for msg.sender.
     */
    function callbackTime() public view returns (uint256) {
        return callbackTimes[msg.sender];
    }

    /**
     * @dev Oraclize getPrice.
     */
    function getPrice() public view returns (uint) {
        return prices[msg.sender];
    }

    /**
     * @dev Sends query to oraclize.
     */
    function updateRate() external returns (bool) {
        updateTimes[msg.sender] = now;
        callbackTimes[msg.sender] = now;
        rates[msg.sender] = mockRate;

        if (prices[msg.sender] == 0) 
            prices[msg.sender] = MOCK_REQUEST_PRICE;

        emit PriceTicker(msg.sender, rates[msg.sender]);
        return true;
    }

    /**
    * @dev Method used for oracle funding   
    */    
    function () public payable { }
}