require("@nomicfoundation/hardhat-toolbox");
// require( 'dotenv' ).config();
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.9",
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
  
    apiKey: "ZNQJK8722M2P9JVA17XUNQIJMUBP4D2GX",
  },
  paths: {
    artifacts: "./src/artifacts",
  },
  networks: {
    hardhat: {
      chainId: 1337

    },
    ropsten: {
      url: ''
      
    },
    rinkeby: {
      url: 'https://rinkeby.infura.io/v3/7dfa03dd8b994c8cb9d5fab7babf558e',
      accounts: ['0xace925254254cd6dd354a53cc78983861121a5f8a1b1673e097664d4d8762fa6']
    }

  }
};