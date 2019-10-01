const GrowdropManager = artifacts.require("GrowdropManager");

module.exports = function(deployer) {
  deployer.deploy(GrowdropManager);
};
