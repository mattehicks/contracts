pragma solidity ^0.4.10;

import "../zeppelin/token/StandardToken.sol";
import "../zeppelin/ownership/Ownable.sol";


/**
 * @title LibreCash token contract.
 *
 * @dev ERC20 token contract.
 */
contract LibreCash is StandardToken, Ownable {
    string public version = "0.1.1";
    string public constant name = "LibreCash Token";
    string public constant symbol = "LCT";
    uint32 public constant decimals = 18;
    uint256 public totalSupply;
    address public bankAddress;
    
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed burner, uint256 value);
    event BankSet(address bankAddress);

    modifier onlyBank() {
        require(msg.sender == bankAddress);
        _;
    }

    /**
     * @dev Constructor.
     */
    function LibreCash(address _bankAddress) public {
        // 0x0 is possible; in this case we need to call setBankAddress later (like in migrations)
        bankAddress = _bankAddress;
        BankSet(_bankAddress);
    }

    /**
     * @dev Sets new bank address.
     * @param _bankAddress The bank address.
     */
    function setBankAddress(address _bankAddress) public onlyOwner {
        require(_bankAddress != 0x0);
        bankAddress = _bankAddress;
        BankSet(_bankAddress);
    }

    /**
     * @dev Minting function.
     * @param _to The address.
     * @param _amount The amount.
     */
    function mint(address _to, uint256 _amount) public onlyBank returns (bool) {
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        Mint(_to, _amount);
        Transfer(address(this), _to, _amount);
        return true;
    }

    /**
     * @dev Burns a specific amount of tokens.
     * @param _value The amount of token to be burned.
     */
    function burn(uint256 _value) public {
        require(_value <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        totalSupply = totalSupply.sub(_value);
        Burn(msg.sender, _value);
        Transfer(msg.sender, 0x0, _value);
    }

    /**
    * @dev Reject all ERC23 compatible tokens
    * @param from_ The address that is transferring the tokens
    * @param value_ the amount of the specified token
    * @param data_ The data passed from the caller.
    */
    function tokenFallback(address from_, uint256 value_, bytes data_) external {
        revert();
    }
}