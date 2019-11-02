const Growdrop = artifacts.require("Growdrop");
const Growdrop_Kovan = artifacts.require("Growdrop_kovan");
const Tokenswap = artifacts.require("Tokenswap");
const DonateToken = artifacts.require("DonateToken");
const GrowdropCall = artifacts.require("GrowdropCall");

module.exports = function(deployer, network) {
  var uniswapfactory;
  var kybernetworkproxy;
  var kyberdai;
  var dai;
  var kyberminimum;
  if(network == "kovan") {
      uniswapfactory="0xD3E51Ef092B2845f10401a0159B2B96e8B6c3D30";
      kybernetworkproxy="0x692f391bCc85cefCe8C237C01e1f636BbD70EA4D";
      kyberdai="0xC4375B7De8af5a38a93548eb8453a498222C4fF2";
      dai="0xbF7A7169562078c96f0eC1A8aFD6aE50f12e5A99";
      kyberminimum="1000000000";

      deployer.deploy(Growdrop_Kovan)
      .then(function() {
        return deployer.deploy(GrowdropCall, Growdrop_Kovan.address);
      }).then(function() {
        return deployer.deploy(
          Tokenswap, 
          Growdrop_Kovan.address,
          uniswapfactory, 
          kybernetworkproxy, 
          dai,
          kyberdai,
          kyberminimum
        );
      }).then(function() {
        return deployer.deploy(DonateToken, Growdrop_Kovan.address);
      })
  } else if (network == "mainnet") {
      uniswapfactory="0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95"
      kybernetworkproxy="0x818E6FECD516Ecc3849DAf6845e3EC868087B755";
      dai="0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359";
      kyberdai="0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359";
      kyberminimum="1000000000000000";

      deployer.deploy(Growdrop)
      .then(function() {
        return deployer.deploy(GrowdropCall, Growdrop.address);
      }).then(function() {
        return deployer.deploy(
          Tokenswap, 
          Growdrop.address,
          uniswapfactory, 
          kybernetworkproxy, 
          dai,
          kyberdai,
          kyberminimum
        );
      }).then(function() {
        return deployer.deploy(DonateToken, Growdrop.address);
      })
  }
}