pragma solidity ^0.4.10;
import "./OracleMockBase.sol";

contract OracleMockSasha is OracleMockBase {
    function OracleMockSasha() {
        oracleName = "Sasha (Mocked Oracle, 30000)";
        rate = 30000;
    }
}