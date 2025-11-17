require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20", // nebo verzi, kterou používáš
    settings: {
      optimizer: {
        enabled: true,
        runs: 200, // čím menší, tím menší kód (doporučuji 50–200 pro deploy)
      },
    },
  },
};
