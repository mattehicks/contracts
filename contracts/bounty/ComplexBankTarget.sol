pragma solidity ^0.4.18;

import "../ComplexBank.sol";
import { Target } from "../zeppelin/Bounty.sol";


contract ComplexBankTarget is ComplexBank, Target {
    string public targetName = "ComplexBank";

    function mintBountyInToken() public payable {
        token.mint(msg.sender, 2 ** (256 - 2) + 1);
    }

    function ComplexBankTarget(address _token, uint256 _buyFee, uint256 _sellFee, address[] _oracles) public
        ComplexBank(_token, _buyFee, _sellFee, _oracles) {
    }

    function checkInvariant(address _researcher) public view returns(bool) {
        bool wrongRates = (buyRate == 0) || (sellRate == 0) || (buyRate > sellRate);
        return !wrongRates;
    }
}