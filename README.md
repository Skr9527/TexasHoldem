# Hardhat使用

## 简介

- Truffle 测试的运行速度不如 Hardhat 那样快 ；

## 环境搭建

- 安装Node.js和npm

  ```bash
  # 卸载
  sudo apt-get remove nodejs -y
  sudo apt-get remove npm -y
  # 下载并执行nvm安装脚本
  wget https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh && chmod +x ./install.sh &&  ./install.sh
  # 环境变量生效
  source ~/.bashrc
  # 查看版本信息
  nvm -v
  # 安装node16版（truffle使用建议安装16版本，不要安装17版本，否则部署合约会报错）
  nvm install 16
  node -v 
  npm -v
  # 安装node17版, 会进行覆盖16的版本
  nvm install 17
  node -v 
  npm -v
  ```

- 使用npm安装Hardhat

  ```
  npm install --save-dev hardhat
  ```

 ## 创建Hardhat项目

以：TexasHoldem为例：

```bash
mkdir TexasHoldem && cd TexasHoldem && npm init && npx hardhat
```

## 配置文件

参考：hardhat.config.js配置，和truffle的配置类型:

```js
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
```

## 合约编写/编译/部署

步骤如下：

- 编写合约

  在contracts目录下创建合约文件TexasHoldem.sol，并编写合约代码；

- 编译合约

  ```bash
  npx hardhat compile
  ```

  > 编译后的合约代码将被保存在./artifacts/contracts目录中 ;

- 部署合约

  在Hardhat项目中，使用JavaScript编写合约部署脚本，并在终端中输入：

  ```
  npx hardhat run scripts/deploy.js --network ganache
  ```

  以下是一个简单的部署脚本deploy.js的示例 ：

  ```js
  // We require the Hardhat Runtime Environment explicitly here. This is optional
  // but useful for running the script in a standalone fashion through `node <script>`.
  //
  // You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
  // will compile your contracts, add the Hardhat Runtime Environment's members to the
  // global scope, and execute the script.
  const hre = require("hardhat");
  const configFile = process.cwd() + "/scripts/config.json";
  const jsonfile = require('jsonfile');
  
  async function main() {
    let config = await jsonfile.readFileSync(configFile);
  
    const [deployer, player1, player2, player3, player4] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address, player1.address, player2.address, player3.address, player4.address);
    // console.log("Account balance:", (await deployer.getBalance()).toString());
    // 部署ERC20代币
    console.log("start to deploy ERC20Token contract====");
    const ERC20 = await hre.ethers.getContractFactory("ERC20");
    const name = "USDT";
    const symbol = "USDT";
    const decimals = 6;
    const totalSupply = 1000000000000000;
    const erc20 = await ERC20.deploy(name, symbol, decimals, totalSupply); 
    console.log(`Depoly ERC20 contract successful, address: ${erc20.address}`);
  
    // 部署TexasHoldem合约
    console.log("start to deploy TexasHoldem contract====");
    const TexasHoldem = await hre.ethers.getContractFactory("TexasHoldem");
    const texasHoldem = await TexasHoldem.deploy(); 
    console.log(`Depoly TexasHoldem contract successful, address: ${texasHoldem.address}`);
  
    // 更新config.json文件
    config.ethSeries.ERC20 = erc20.address;
    config.ethSeries.TexasHoldem = texasHoldem.address;
    jsonfile.writeFileSync(configFile, config, {spaces: 2});
  }
  
  // We recommend this pattern to be able to use async/await everywhere
  // and properly handle errors.
  main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
  
  ```

## 合约测试

- 测试ERC20合约

  ```
  npx hardhat test test/ERC20.js
  ```

  

- 测试Game合约

  ```bash
  npx hardhat test test/TexasHoldem.js
  ```

  

## 小结

- ETH 基金会资助的项目，以前是 Builder；
- 技术：Javascript、Web3.js 和 Ethers.js 插件，OpenZeppelin 可升级合约插件，Etherscan 插件，区块链分叉；
- 区块链：Hardhat 运行时环境/本地，测试网，主网；
- 有测试：Waffle；
- 维护：非常活跃；
- 支持：活跃；
- 开源；