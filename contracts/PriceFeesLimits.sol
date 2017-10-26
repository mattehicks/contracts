pragma solidity ^0.4.10;

import "./zeppelin/math/SafeMath.sol";
import "./zeppelin/ownership/Ownable.sol";

/**
 * @title PriceFeesLimits.
 *
 * @dev Contract.
 */
contract PriceFeesLimits is Ownable {
    using SafeMath for uint256;

    uint256 public currencyUpdateTime;

    uint256 public cryptoFiatRate;
    uint256 public cryptoFiatRateSell;
    uint256 public cryptoFiatRateBuy;

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
    function setRateLimits(uint256 _min, uint256 _max) public onlyOwner {
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
    function setBuyFee(uint256 _fee) public onlyOwner {
        require (_fee < 300000); // fee less than 300%
        buyFee = _fee;
    }

    /**
     * @dev Sets selling eee.
     * @param _fee The fee in percent (100% = 10000).
     */
    function setSellFee(uint256 _fee) public onlyOwner {
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
}