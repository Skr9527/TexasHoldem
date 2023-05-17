const { expect } = require("chai");

describe("ERC20", function () {
  let ERC20Token;
  let erc20;
  let deployer;
  let to;
  let addr2;
  let addr3;
  const name = "USDT";
  const symbol = "USDT";
  const decimals = 6;
  const totalSupply = 1000000000000000;

  beforeEach(async function () {
    [deployer, to, addr2, addr3] = await ethers.getSigners();
    ERC20Token = await ethers.getContractFactory("ERC20");
    erc20 = await ERC20Token.deploy(name, symbol, decimals, totalSupply); 
  });

  describe("Token Info", function () {
    it("Should be obtained the correct token name", async function () {
      expect(await erc20.name()).to.equal(name);
    });


    it("Should be obtained the correct token symbol", async function () {
      expect(await erc20.symbol()).to.equal(symbol);
    });

    it("Should be obtained the correct token decimals", async function () {
      expect(await erc20.decimals()).to.equal(decimals);
    });

    it("Should be obtained the correct token balance", async function () {
      expect(await erc20.balanceOf(deployer.address)).to.equal(totalSupply);
    });
  });

  describe("Transfer", function () {
    it("Should be transfer the specified amount of tokens correctly", async function () {
      const amount = totalSupply / 1000;
      await erc20.transfer(to.address, amount);
      expect(await erc20.balanceOf(to.address)).to.equal(amount);
      expect(await erc20.balanceOf(deployer.address)).to.equal(totalSupply - amount);
    });

    it("Should be approval and transfer from approval amount of tokens correctly", async function () {
      const amount = totalSupply / 1000;
      await erc20.approve(to.address, amount);
      // 查询
      expect(await erc20.allowance(deployer.address, to.address)).to.equal(amount);
      
      expect(await erc20.balanceOf(to.address)).to.equal(0);

      // 转账（连接to地址，使用to地址发送合约交易）
      await erc20.connect(to).transferFrom(deployer.address, addr2.address, amount);
      expect((await erc20.balanceOf(addr2.address))).to.equal(amount);
      // 授权金额为0
      expect(await erc20.allowance(deployer.address, to.address)).to.equal(0);
    });
  });

  describe("Events", function () {
    it("Should emit an event on transfer", async function () {
      const amount = totalSupply / 1000;
      await expect(erc20.transfer(to.address, amount))
        .to.emit(erc20, "Transfer")
        .withArgs(deployer.address, to.address, amount); // 事件参数
    });

    it("Should emit an event on approve and transferFrom", async function () {
      const amount = totalSupply / 1000;
      await expect(erc20.approve(to.address, amount))
        .to.emit(erc20, "Approval")
        .withArgs(deployer.address, to.address, amount); // 事件参数

      await expect(erc20.connect(to).transferFrom(deployer.address, addr2.address, amount))
        .to.emit(erc20, "Transfer")
        .withArgs(deployer.address, addr2.address, amount); // 事件参数
    });
  });
});
