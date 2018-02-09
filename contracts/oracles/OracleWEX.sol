pragma solidity ^0.4.17;

import "./OracleBase.sol";

/**
 * @title WEX.NZ oracle.
 *
 * @dev https://wex.nz/.
 */
contract OracleWEX is OracleBase {
    // the comment is reserved for API documentation :)
    bytes32 constant ORACLE_NAME = "WEX Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    string constant ORACLE_ARGUMENTS = "json(https://wex.nz/api/3/ticker/eth_usd).eth_usd.last";

    /**
     * @dev Constructor.
     */
    function OracleWEX() public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
    }
}