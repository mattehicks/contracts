pragma solidity ^0.4.10;

import "./zeppelin/lifecycle/Pausable.sol";
import "./zeppelin/math/SafeMath.sol";


interface token {
    /*function transfer(address receiver, uint amount);*/
    function balanceOf(address _owner) returns (uint256);
    function mint(address _to,uint256 _amount);
    function getTokensAmount() public returns(uint256);
}

interface oracleInterface {
    function update();
    function getName() constant returns(string);
}

contract libreBank is Ownable,Pausable {
    using SafeMath for uint256;
    
    enum limitType { minUsdRate, maxUsdRate, minTransactionAmount, minTokensAmount, minSellSpread, maxSellSpread, minBuySpread, maxBuySpread }
    event newPriceTicker(string oracleName, string price);
    event LogBuy(address clientAddress, uint256 tokenAmount, uint256 etherAmount, uint256 buyPrice);
    event LogSell(address clientAddress, uint256 tokenAmount, uint256 etherAmount, uint256 sellPrice);
    /*
    event LogWhithdrawal (uint256 EtherAmount, address addressTo, uint invertPercentage);
    */

 /*   struct oracleData {
        string name;
        address oracleAddress; // Maybe replace it on mapping (see below)
        uint256 rating;
        bool enabled;
    }

    oracleData[] oracles;*/
    uint256 updateDataRequest;
    
 /*   mapping (string=>address) oraclesAddress;*/

// begin new oracleData - dima
    struct oracleData {
        string name;
        uint256 rating;
        bool enabled;
        bool waiting;
        uint256 updateTime; // time of callback
        uint256 rate; // exchange rate
    }

    mapping (address=>oracleData) oracles;
    address[] oracleAdresses;

    uint256 numWaitingOracles = 2**256 - 1; // init as maximum
    uint256 numEnabledOracles;
    // maybe we should add weightWaitingOracles - sum of rating of waiting oracles
    uint256 timeUpdateRequested;
// end new oracleData
 
    uint256 public currencyUpdateTime;
    uint256 public ethUsdRate = 30000; // In $ cents

    uint256[] limits;
    oracleInterface currentOracle;
    token libreToken;
    uint256 minTokenAmount = 1; // used in sellTokens(...)
    uint256 buyPrice; // in cents
    uint256 sellPrice; // in cents
    uint256 currentSpread; // in cents

    function setLimitValue(limitType limitName, uint256 value) internal {
        limits[uint(limitName)] = value;
    }

    function getLimitValue(limitType limitName )internal returns (uint256) {
        return limits[uint(limitName)];
    }

    function getMinTransactionAmount() constant external returns(uint256) {
        return getLimitValue(limitType.minTransactionAmount);
    }
    
    function setMinTransactionAmount(uint256 amountInWei) onlyOwner {
        setLimitValue(limitType.minTransactionAmount,amountInWei);
    }

    function setBuySpreadLimits(uint256 _minBuySpread, uint256 _maxBuySpread) onlyOwner {
        setLimitValue(limitType.minBuySpread, _minBuySpread);
        setLimitValue(limitType.maxBuySpread, _maxBuySpread);
        
    }

    function setSellSpreadLimits(uint256 _minSellSpread, uint256 _maxSellSpread) onlyOwner {
        setLimitValue(limitType.minSellSpread, _minSellSpread);
        setLimitValue(limitType.maxSellSpread, _maxSellSpread);
    }

    function setSpread(uint256 _buySpread, uint256 _sellSpread) onlyOwner {
        require(_buySpread > getLimitValue(limitType.minBuySpread) && _buySpread < getLimitValue(limitType.maxBuySpread));
        require(_sellSpread > getLimitValue(limitType.minSellSpread) && _sellSpread < getLimitValue(limitType.maxSellSpread));
        buySpread = _buySpread;
        sellSpread = _sellSpread;
    }

    function addOracle(address oracleAddress) onlyOwner {
        require(oracleAddress != 0x0);
        oracleInterface(oracleAddress);
        oracleData memory thisOracle = new oracleData(oracleInterface.getName(),oracleAddress,0,true);
        oracles.push(thisOracle);
    }
    function getOracleName(uint number) public constant returns(string) {
        return oracles[number].name;
    }
    
    // Ограничие на периодичность обновления курса - не чаще чем раз в 5 минут
    modifier needUpdate() {
        require(!isRateActual());
        _;
    }

    function isRateActual() public constant returns(bool) {
        return now <= currencyUpdateTime + 5 minutes;
    }

    function libreBank(address coinsContract) {
        libreToken = token(coinsContract);
    }
    
    function donate() payable {}

    function getTokenPrice() returns(uint256) {
        // Implement price calc logic later
        uint256 tokenPrice = 100; // In $ cent
        return tokenPrice;
    }

    

    function setTokenToSell(address tokenAddress) onlyOwner {
        libreToken = token(tokenAddress);
    }

    function totalTokens() returns (uint256) {
        return libreToken.getTokensAmount();
    }



    function withdrawEther(address beneficiar) onlyOwner {
        beneficiar.send(this.balance);
    }


    function setCurrencyRate(uint256 rate) onlyOwner {
        bool validRate = rate > 0 && rate < getLimitValue(limitType.maxUsdRate) && rate > getLimitValue(limitType.minUsdRate);
        require(validRate);
        ethUsdRate = rate;
        currencyUpdateTime = now;
    }

    function updateRate() needUpdate {
        requestUpdateRates();
        // I think we don't need the next code
        // the function should wait for callbacks or we should change the way it works
        // !!!!
        // следующий код здесь не нужен
        // нужно или ждать тут колбэки или не использовать эту функцию

        /*currentSpread = SafeMath.add(limits[limitType.minBuySpread], limits[limitType.minSellSpread]);
        uint256 halfSpread = SafeMath.div(currentSpread, 2);
        // require(halfSpread < currentSpread); // -- not sure if we need to check (possibly no), I need to research types and possible vulnerabilities - Dima
        buyPrice = SafeMath.sub(ethUsdRate, halfSpread);
        sellPrice = SafeMath.add(ethUsdRate, halfSpread);*/
    }

    function requestUpdateRates() private returns (bool) {
        uint256[] oracleResults;
        for (uint256 i = 0; i < oracles.length; i++) {
            // numWaitingOracles goes -1 after each callback
            numWaitingOracles = 0;
            if (oracles[i].enabled) {
                oracleInterface(oracleAddresses[i]).update();
                oracle[i].waiting = true;
                numWaitingOracles++;
            }
            timeUpdateRequested = now;
            if (numWaitingOracles <= 2) { return false; } // 1-2 enabled oracles - false result. we need more oracles
            // but we can not refer to return (i don't do throw here because update() already sent) - think about number of needed oracles
            return true;
        } // foreach oracles
    }

    function getRate() private returns (bool) {
        // check if numWaitingOracles is small enough in compare with all oracles
        require (numWaitingOracles < 3);
        require ((numWaitingOracles!=0) && (numEnabledOracles-numWaitingOracles>3)); // if numWaitingOracles not zero, check if count of ready oracles > 3
                                                                                  // TODO: think about oracle weight and maybe use weights instead of count (num...) 
        uint256 numReadyOracles = 0;
        uint256 sumRatings = 0;
        uint256 integratedRates = 0;
        // the average rate would be: (sum of rating*rate)/(sum of ratings)
        // so the more rating oracle has, the more powerful his rate is
        for (uint i = 0; i < oracleAdresses.length; i++) {
            oracleData currentOracle = oracles[oracleAdresses[i]];
            if (now <= currentOracle.updateTime + 5 minutes) { //up to date
                if (currentOracle.enabled) {
                    numReadyOracles++;
                    // values for calculating the rate
                    sumRatings += currentOracle.rating;
                    integratedRates += SaveMath.mul(currentOracle.rating, currentOracle.rate);
                }
            } // if up to time
            else { // oracle's rate is older than 5 mins
                // just nothing? we don't increment readyOracles
            } // if old data
        } // foreach oracles
        require (numReadyOracles > 2); // maybe change/add rating of oracles
        require (numEnabledOracles.div(numReadyOracles) < 2); // numReadyOracles!=0 is already; need more than 50% ready oracles
        // here we can count the rate and return true
        uint256 finalRate = SaveMath.div(integratedRates, sumRatings); // formula is in upper comment
        setCurrencyRate(finalRate);
        return true;
    }

    function oraclesCallback(address _address, uint256 _rate, uint256 _time) {
        // Implement it later
        if (!oracles[i].waiting) {
            // we didn't wait for this oracul
            // to do - think what to do, this information is useful, but why it is late or not wanted?
        }
        else
        {
            // all ok, we waited for it
            numWaitingOracles--;
            // maybe we should check for existance of structure oracles[_address]? to think about it
            oracles[_address].rate = _rate;
            oracles[_address].updateTime = _time;
            oracles[i].waiting = false;
            // we don't need to update oracle name, so?
            // so i deleted 'string name' from func's arguments
        }
        // so this callback function JUST updates the gotten rate value and timestamp
        // new getRate function checks if we can count the rate (due to count of good callbacks) and counts
        // we shold call getRate when we need it       
    }

    // ***************************************************************************

    // Buy token by sending ether here
    //
    // Price is being determined by the algorithm in oraclesCallback()
    // You can also send the ether directly to the contract address   
    
    OrderData[] Orders; // очередь ордеров
    struct OrderData {
        bool isBuy; // True = Buy, False = sell
        address clientAddress;
        uint256 orderAmount;
        uint256 orderTimestamp;
        //uint ClientLimit;
    } 

    function () payable external {
        buyTokens(msg.sender);
    }

    function buyTokens () payable public {
        buyTokens(msg.sender);
    }

    function buyTokens (address benificiar) payable public {
        require(msg.value > getLimitValue(limitType.minTransactionAmount));
        if (!isRateActual) {                   // проверяем курс на актуальность
            Orders.push (true,msg.value,now); // ставим ордер в очередь
            updateRate(); //                     и выходим из функции
            }
        // in case of possible overflows should do assert() or require() for sellPrice>ethUsdRate and buyPrice<..., but we need a small research
        uint256 tokensAmount;
        tokensAmount = msg.value.mul(buyPrice).div(100);  
        libreToken.mint(benificiar, tokensAmount);
        LogBuy(benificiar, tokensAmount, msg.value, buyPrice);
    }

    function buyAfter (uint256 orderID) internal {
        // in case of possible overflows should do assert() or require() for sellPrice>ethUsdRate and buyPrice<..., but we need a small research
        uint256 ethersAmount = Orders[orderID].orderAmount;
        uint256 tokensAmount = ethersAmount.mul(buyPrice).div(100);
        address benificiar = Orders[orderID].clientAddress;  
        libreToken.mint(benificiar, tokensAmount);
        LogBuy(benificiar, tokensAmount, ethersAmount, buyPrice);
    }
  
    function sellTokens(uint256 _amount) public {
        require (libreToken.balanceOf(msg.sender) >= _amount);        // checks if the sender has enough to sell
        require (_amount >= getLimitValue(limitType.minTokensAmount));
        uint256 tokensAmount;
        uint256 ethersAmount = _amount.div(sellPrice).mul(100);
        if (ethersAmount > this.balance) {                  // checks if the bank has enough Ethers to send
            tokensAmount = this.balance.mul(sellPrice).div(100); // нужна дополнительная проверка, на случай повторного запроса при пустых резервах банка
            ethersAmount = this.balance;
        } else {
            tokensAmount = _amount;
        }
        if (!isRateActual) {                   // проверяем курс на актуальность
            libreToken.burn(msg.sender, tokensAmount); // уменьшаем баланс клиента (в случае отмены ордера, токены клиенту возвращаются)
            Orders.push (false,tokensAmount,now); // ставим ордер в очередь
            updateRate(); //                     и выходим из функции
            }
        
        if (msg.sender.transfer(ethersAmount)) {   
            libreToken.burn(msg.sender, tokensAmount);                                        
        } 
        LogSell(msg.sender, tokensAmount, ethersAmount, sellPrice);
    }

    function sellAfter (uint256 orderID) internal {
        address benificiar = Orders[orderID].clientAddress;
        uint256 tokensAmount = Orders[orderID].orderAmount;
        uint256 ethersAmount = tokensAmount.div(sellPrice).mul(100);
        if (ethersAmount > this.balance) {                  // checks if the bank has enough Ethers to send
            tokensAmount = this.balance.mul(sellPrice).div(100); 
            libreToken.mint(benificiar, Orders[orderID].orderAmount.sub(tokensAmount));
            ethersAmount = this.balance;
        } else {
            tokensAmount = Orders[orderID].orderAmount;
            ethersAmount = tokensAmount.div(sellPrice).mul(100);
        }
        if (!benificiar.send(ethersAmount)) { 
            libreToken.mint(benificiar, tokensAmount);
            throw;                                         
        } 
        LogSell(benificiar, tokensAmount, ethersAmount, sellPrice);
    }

    function clearOrders () internal {
        uint ordersLength = Orders.length;
        for (uint i = 0; i < ordersLength; i++) {
            if (Orders[i].isBuy) {
                buyAfter (i); 
            } else {sellAfter (i);}
        }
        for (i = 0; i < ordersLength; i++) {
            delete  Orders[0];
        }
    }
}


