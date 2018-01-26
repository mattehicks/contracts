pragma solidity ^0.4.17;
import "./OracleMockBase.sol";

/**
 * @title Mocked oracles contract for testing purposes.
 */
contract OracleMockTest is OracleMockBase {
    function OracleMockTest() {
        oracleName = "Test (Mocked Oracle, 1000)";
        rate = 1000;
    }
}