require("@nomicfoundation/hardhat-toolbox");
const config = require("./scripts/config.json");

//选取ganache下的5个账户的私钥
// const PRIVATE_KEY1 = "02da90597bf4cef6621103622f27a31d65c0856a0a66ba2fd03e4663161f1c5b"; // 0x86d5b5903b0330d76b47D368bebF5A74dB6251dB
// const PRIVATE_KEY2 = "ef0ad8f183e9b39f801ce9ba03b8f332fbe338344a207c9995966795aa295970"; // 0xc3899703e578f13802c0F83Fb5Ee114a139910f0
// const PRIVATE_KEY3 = "51b50bc613d2479f1c4bf1447df03c5d64308734567ef4532a0ca5457660c6b7"; // 0x6A311b9D42Ea0Cb4F62760383C0EfF06Ac68F1f7
// const PRIVATE_KEY4 = "643bed802290c623d29187052391f6570ba40f5c4a5c73665d1ebc7141467401"; // 0x57FFbD5b047aDe5482abFDfc19c9E09EC7D1F995
// const PRIVATE_KEY5 = "ee378ce4b0e8727adbe134efcf5c653103f8ed81cd4fd719d69cb5f31f30d5d5"; // 0x8FD2C3a4C63941611Dad485890C90A101D08402b

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  // 定义网络
  networks: {
    // hardhat网络
    hardhat: {
      chainId: 1337
    },

    // ganache本地网络
    ganache: {
      url: `http://192.168.31.234:8545`,
      // 私钥方式
      // accounts: [`0x${PRIVATE_KEY1}`,`0x${PRIVATE_KEY2}`,`0x${PRIVATE_KEY3}`,`0x${PRIVATE_KEY4}`,`0x${PRIVATE_KEY5}`],
      // 助记词方式
      accounts: {
        mnemonic: config.ethSeries.mnemonic,
      },
    },
  }
}