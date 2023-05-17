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
