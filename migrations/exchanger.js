const
    oraclesDeploy = require('./oracles.js'),
    contractConfig = require('./config.js');

module.exports = async function (deployer, contracts, config) {
    let [cash, exchanger, ...oracles] = contracts;

    await oraclesDeploy(deployer, oracles);
    let _oracles = await Promise.all(oracles.map((oracle) => oracle.deployed()));
    let oraclesAddress = oracles.map((oracle) => oracle.address);

    await deployer.deploy(cash);
    let _cash = await cash.deployed();

    await deployer.deploy(
        exchanger,
        /* Constructor params */
        cash.address, // Token address
        config.buyFee, // Buy Fee
        config.sellFee, // Sell Fee,
        oraclesAddress, // oracles (array of address)
        config.deadline,
        web3
    );
    await exchanger.deployed();

    await Promise.all(_oracles.map((oracle) => oracle.setBank(exchanger.address)));

    await _cash.mint.sendTransaction(exchanger.address, contractConfig.Exchanger.mintAmount);
    await _cash.mint.sendTransaction(web3.eth.coinbase, contractConfig.main.cashMinting);
};
