var fs = require('fs');

rimraf("build/contracts");

let testnetLocal = false;

if (testnetLocal) {
  var contracts = ['LocalRPCBank'];

  var contractsToDeploy = {};
  contracts.forEach(function(name) {
    contractsToDeploy[name] = artifacts.require("./" + name + ".sol");
  });

  module.exports = function(deployer) {
    contracts.forEach(function(contractName) {
      let artifact = artifacts.require("./" + contractName + ".sol");

      deployer.deploy(artifact).then(function() {
        artifact.deployed().then(function(instance) {

        });
      });
    });
  };
}
// ************************************************************************************************** //
else {
  var contracts = ['LibreCash',
                 'OracleBitfinex',
                 'OracleBitstamp',
                 //'OracleGDAX',
                 //'OracleGemini',
                 //'OracleKraken',
                 'OracleWEX',
                 'BasicBank'
                ];

  var contractsToDeploy = {};
  contracts.forEach(function(name) {
    contractsToDeploy[name] = artifacts.require("./" + name + ".sol");
  });

  module.exports = function(deployer) {
    contracts.forEach(function(contractName) {
      let artifact = artifacts.require("./" + contractName + ".sol");

      deployer.deploy(artifact).then(function() {
        artifact.deployed().then(function(instance) {
          // в функции ниже ставим зависимости, она не для финального деплоя
          temporarySetDependencies(contractName, instance);
          var contractABI = JSON.stringify(artifact._json.abi);
          var contractAddress = artifact.address;
          writeDeployedContractData(contractName, contractAddress, contractABI);
        });
      });
    }); // foreach
    finalizeDeploy();
  };

  var oracleAddresses = [];
  var tokenAddress;
  function temporarySetDependencies(contractName, instance) {
    if (contractName.substring(0, 6) == "Oracle") {
      oracleAddresses.push(instance.address);
    }
    if (contractName == "LibreCash") {
      tokenAddress = instance.address;
    }
    if (contractName == "BasicBank") {
      oracleAddresses.forEach(function(oracleAddress) {
        instance.addOracle(oracleAddress);
      });
      instance.attachToken(tokenAddress);
      instance.setRateLimits(10000, 40000); // 100$ to 400$ eth/usd
    }
  }

  function finalizeDeploy() {
    var directory = "web3tests/";
    var fileName = "listContracts.js";
    var jsData = "var contracts = [{0}];";
    var listOfContracts = "";
    contracts.forEach(function(contractName) {
      listOfContracts += "'{0}', ".replace("{0}", contractName);
    });
    var stream = fs.createWriteStream(directory + fileName);
    stream.once('open', function(fd) {
      stream.write(jsData.replace("{0}", listOfContracts));
      stream.end();
    });
  }

  function writeDeployedContractData(contractName, contractAddress, contractABI) {
    try {
      fs.unlinkSync("build/contracts/" + contractName + ".json");
    } catch (err) {
      console.log(err.message);
    }
    var directory = "web3tests/data/";
    var fileName = contractName + ".js";
    var stream = fs.createWriteStream(directory + fileName);
    stream.once('open', function(fd) {
      let contractData = {
        "contractName": contractName,
        "contractAddress": contractAddress,
        "contractABI": contractABI
      }
      stream.write("contractName = '{0}';\r".replace('{0}', contractData.contractName));
      stream.write("contractAddress = '{0}\r';".replace('{0}', contractData.contractAddress));
      stream.write("contractABI = '{0}';\r".replace('{0}', contractData.contractABI));
      stream.end();
    });
  }
}

// удаление папки
function rimraf(dir_path) {
  if (fs.existsSync(dir_path)) {
      fs.readdirSync(dir_path).forEach(function(entry) {
          var entry_path = path.join(dir_path, entry);
          if (fs.lstatSync(entry_path).isDirectory()) {
              rimraf(entry_path);
          } else {
              fs.unlinkSync(entry_path);
          }
      });
      fs.rmdirSync(dir_path);
  }
}

