const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const DMPS = artifacts.require("DMPS");

module.exports = async function(deployer) {

    await deployProxy(DMPS, { deployer, kind: "uups" });
    // await upgradeProxy("0xcA00FEB3205FA30A3230A29B3bbB8E90d7Cf2d53", DMPS, { deployer, kind: "uups" });
};