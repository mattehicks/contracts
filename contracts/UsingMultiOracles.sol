pragma solidity ^0.4.10;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/ownership/Ownable.sol";

interface oracleInterface {
    function updateRate() payable public;
    function getName() constant public returns (bytes32);
    function setBank(address _bankAddress) public;
    function hasReceivedRate() public returns (bool);
}


/**
 * @title UsingMultiOracles.
 *
 * @dev Contract.
 */
contract UsingMultiOracles is Ownable {
    using SafeMath for uint256;

    event InsufficientOracleData(string description, uint256 oracleCount);
    event OraclizeStatus(address indexed _address, bytes32 oraclesName, string description);
    event OraclesTouched(string description);
    event OracleAdded(address indexed _address, bytes32 name);
    event OracleEnabled(address indexed _address, bytes32 name);
    event OracleDisabled(address indexed _address, bytes32 name);
    event OracleDeleted(address indexed _address, bytes32 name);
    event OracleTouched(address indexed _address, bytes32 name);
    event OracleCallback(address indexed _address, bytes32 name, uint256 result);
    event TextLog(string data);

    struct OracleData {
        bytes32 name;
        uint256 rating;
        bool enabled;
        bool waiting;
        uint256 updateTime; // time of callback
        uint256 cryptoFiatRate; // exchange rate
        uint listPointer; // чтобы знать по какому индексу удалять из массива oracleAddresses
    }

    mapping (address=>OracleData) oracles;
    address[] oracleAddresses;



    // пока на все случаи возможные
    uint256 constant MIN_ENABLED_ORACLES = 0; //2;
    uint256 constant MIN_WAITING_ORACLES = 2; //количество оракулов, которое допустимо омтавлять в ожидании
    uint256 constant MIN_READY_ORACLES = 1; //2;
    uint256 constant MIN_ENABLED_NOT_WAITING_ORACLES = 1; //2;
    uint constant MAX_ORACLE_RATING = 10000;

    uint256 public numWaitingOracles;
    uint256 public numEnabledOracles;
    uint256 public currencyUpdateTime;

    uint256 public cryptoFiatRate;
    uint256 public cryptoFiatRateSell;
    uint256 public cryptoFiatRateBuy;

    // maybe we should add weightWaitingOracles - sum of rating of waiting oracles
    uint256 timeUpdateRequested;

    enum limitType { minCryptoFiatRate, maxCryptoFiatRate, minTokensBuy, minTokensSell, maxTokensBuy, maxTokensSell }
    mapping (uint => uint256) limits;

    uint256 public sellFee = 10000;
    uint256 public buyFee = 10000;
    uint256 public sellSpread = 500; // 5 dollars
    uint256 public buySpread = 500; // 5 dollars


    /**
     * @dev Sets fiat rate limits.
     * @param _min Min rate.
     * @param _max Max rate.
     */
    function setRateLimits(uint256 _min, uint256 _max) public /*onlyOwner*/ {
        setLimitValue(limitType.minCryptoFiatRate, _min);
        setLimitValue(limitType.maxCryptoFiatRate, _max);
    }

    /**
     * @dev Sets fiat rate limits via range.
     * @param _percent Value in percent in both directions (100% = 10000).
     */
    function setRateRange(uint256 _percent) public {
        require (cryptoFiatRate > 0);
        require ((_percent < 10000) && (_percent > 0));
        uint256 _min = cryptoFiatRate.mul(10000 - _percent).div(10000);
        uint256 _max = cryptoFiatRate.mul(10000 + _percent).div(10000);
        setRateLimits(_min, _max);
    }

    /**
     * @dev Sets buying fee.
     * @param _fee The fee in percent (100% = 10000).
     */
    function setBuyFee(uint256 _fee) public {
        require (_fee < 300000); // fee less than 300%
        buyFee = _fee;
    }

    /**
     * @dev Sets selling eee.
     * @param _fee The fee in percent (100% = 10000).
     */
    function setSellFee(uint256 _fee) public {
        require (_fee < 300000); // fee less than 300%
        sellFee = _fee;
    }

    /**
     * @dev Sets one of the limits.
     * @param _limitName The limit name.
     * @param _value The value.
     */
    function setLimitValue(limitType _limitName, uint256 _value) internal {
        limits[uint(_limitName)] = _value;
    }

    /**
     * @dev Gets value of one of the limits.
     * @param _limitName The limit name.
     */
    function getLimitValue(limitType _limitName) constant internal returns (uint256) {
        return limits[uint(_limitName)];
    }

    /**
     * @dev Gets min crypto fiat rate.
     */
    function getMinimumCryptoFiatRate() public view returns (uint256) {
        return getLimitValue(limitType.minCryptoFiatRate);
    }

    /**
     * @dev Gets max crypto fiat rate.
     */
    function getMaximumCryptoFiatRate() public view returns (uint256) {
        return getLimitValue(limitType.maxCryptoFiatRate);
    }

    /**
     * @dev Sets currency rate and updates timestamp.
     */
    function setCurrencyRate(uint256 _rate) internal {
//        bool validRate = (_rate > getLimitValue(limitType.minUsdRate)) && (_rate < getLimitValue(limitType.maxUsdRate));
//        require(validRate);
        cryptoFiatRate = _rate;
        currencyUpdateTime = now;
        cryptoFiatRateSell = _rate.add(sellSpread.mul(sellFee).div(10000));
        cryptoFiatRateBuy = _rate.sub(buySpread.mul(buyFee).div(10000));
    }


    /**
     * @dev Gets oracle count.
     */
    function getOracleCount() public view returns (uint) {
        return oracleAddresses.length;
    }

    // не забываем потом добавить соотв. модификатор
    /**
     * @dev Adds an oracle.
     * @param _address The oracle address.
     */
    function addOracle(address _address) public {
        require(_address != 0x0);
        oracleInterface currentOracleInterface = oracleInterface(_address);
        // TODO: возможно нам не нужно обращаться к оракулу лишний раз
        // только чтобы имя получить?
        // возможно, стоит добавить параметр name в функцию, тем самым упростив всё
        bytes32 oracleName = currentOracleInterface.getName();
        OracleData memory thisOracle = OracleData({name: oracleName, rating: MAX_ORACLE_RATING.div(2), 
                                                    enabled: true, waiting: false, updateTime: 0, cryptoFiatRate: 0, listPointer: 0});
        oracles[_address] = thisOracle;
        // listPointer - индекс массива oracleAddresses с адресом оракула. Надо для удаления
        oracles[_address].listPointer = oracleAddresses.push(_address) - 1;
        currentOracleInterface.setBank(address(this));
        numEnabledOracles++;
        OracleAdded(_address, oracleName);
    }

    // не забываем потом добавить соотв. модификатор
    /**
     * @dev Disable oracle.
     * @param _address The oracle address.
     */
    function disableOracle(address _address) public {
        oracles[_address].enabled = false;
        OracleDisabled(_address, oracles[_address].name);
        if (numEnabledOracles!=0) {
            numEnabledOracles--;
        }
    }

    // не забываем потом добавить соотв. модификатор
    /**
     * @dev Enable oracle.
     * @param _address The oracle address.
     */
    function enableOracle(address _address) public {
        oracles[_address].enabled = true;
        OracleEnabled(_address, oracles[_address].name);
        numEnabledOracles++;
    }

    // не забываем потом добавить соотв. модификатор
    /**
     * @dev Delete oracle.
     * @param _address The oracle address.
     */
    function deleteOracle(address _address) public {
        OracleDeleted(_address, oracles[_address].name);
        // может быть не стоит удалять ждущие? обсудить - Дима
        if (oracles[_address].waiting) {
            numWaitingOracles--;
        }
        if (oracles[_address].enabled) {
            numEnabledOracles--;
        }
        // так. из мэппинга оракулов по адресу получаем индекс в массиве оракулов с адресом оракула
        uint indexToDelete = oracles[_address].listPointer;
        // теперь получаем адрес последнего оракула из массива адресов
        address keyToMove = oracleAddresses[oracleAddresses.length - 1];
        // перезаписываем удаляемый оракул последним (в массиве адресов)
        oracleAddresses[indexToDelete] = keyToMove;
        // а в мэппинге удалим
        delete oracles[_address];
        // у бывшего последнего оракула из массива адресов теперь новый индекс в массиве
        oracles[keyToMove].listPointer = indexToDelete;
        // уменьшаем длину массива адресов, адрес в конце уже на месте удалённого стоит и нам не нужен
        oracleAddresses.length--;
    }

    /**
     * @dev Gets oracle name.
     * @param _address The oracle address.
     */
    function getOracleName(address _address) public view returns(bytes32) {
        return oracles[_address].name;
    }
    
    /**
     * @dev Gets oracle rating.
     * @param _address The oracle address.
     */
    function getOracleRating(address _address) public view returns(uint256) {
        return oracles[_address].rating;
    }

    /**
     * @dev Gets oracle rate.
     * @param _address The oracle address.
     */
    function getOracleRate(address _address) public view returns(uint256) {
        return oracles[_address].cryptoFiatRate;
    }

    /**
     * @dev Funds each oracle till its balance is 0.2 eth (TODO: make a var for 0.2 eth).
     */
    function fundOracles() public payable {
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            /* 200 finney = 0.2 ether */
            if (oracleAddresses[i].balance < 200 finney) {
               oracleAddresses[i].transfer(200 finney - oracleAddresses[i].balance);
            }
        } // foreach oracles
    }

    // про видимость подумать
    /**
     * @dev Touches oracles asking them to get new rates.
     */
    function requestUpdateRates() public {
        require (numEnabledOracles >= MIN_ENABLED_ORACLES);
        numWaitingOracles = 0;
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            if (oracles[oracleAddresses[i]].enabled) {
                oracleInterface(oracleAddresses[i]).updateRate();
                OracleTouched(oracleAddresses[i], oracles[oracleAddresses[i]].name);
                oracles[oracleAddresses[i]].waiting = true;
                numWaitingOracles++;
            }
            timeUpdateRequested = now;
        } // foreach oracles
        OraclesTouched("Запущено обновление курсов");
    }

    // подумать над видимостью
    /**
     * @dev Calculates crypto/fiat rate from "oracles" array.
     */
    function calculateRate() public {
        require (numWaitingOracles <= MIN_WAITING_ORACLES);
        require (numEnabledOracles-numWaitingOracles >= MIN_ENABLED_NOT_WAITING_ORACLES);

        uint256 numReadyOracles = 0;
        uint256 sumRating = 0;
        uint256 integratedRates = 0;
        // the average rate would be: (sum of rating*rate)/(sum of ratings)
        // so the more rating oracle has, the more powerful his rate is
        for (uint i = 0; i < oracleAddresses.length; i++) {
            OracleData storage currentOracleData = oracles[oracleAddresses[i]];
            if (now <= currentOracleData.updateTime + 3 minutes) { // защита от флуда обновлениями, потом мб уберём
                if (currentOracleData.enabled) {
                    numReadyOracles++;
                    sumRating += currentOracleData.rating;
                    integratedRates += currentOracleData.rating.mul(currentOracleData.cryptoFiatRate);
                }
            }
        }
        require (numReadyOracles >= MIN_READY_ORACLES);

        uint256 finalRate = integratedRates.div(sumRating); // the formula is in upper comment
        setCurrencyRate(finalRate);
    }

    /**
     * @dev The callback from oracles.
     * @param _address The oracle address.
     * @param _rate The oracle ETH/USD rate.
     * @param _time Update time sent from oracle.
     */
    function oraclesCallback(address _address, uint256 _rate, uint256 _time) public {
        if (!oracles[_address].waiting) {
            TextLog("Oracle not waiting");
        } else {
            OracleCallback(_address, oracles[_address].name, _rate);
            // all ok, we waited for it
            numWaitingOracles--;
            // maybe we should check for existance of structure oracles[_address]? to think about it
            oracles[_address].cryptoFiatRate = _rate;
            oracles[_address].updateTime = _time;
            oracles[_address].waiting = false;
        }
    }
}