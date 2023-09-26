const { expect } = require("chai");
const { network } = require("hardhat");

describe("TexasHoldem", function () {
  // 同步标志：私链（单节点） -- 交易可以立即上链，可以立即查询交易回执；多节点 -- 交易上链会有延迟
  let syncFlag = true;
  // 使用异步方式的网络名称
  const asyncNetsFlag = ["hardhat", "ganache", "local"];
  let waitTxs = [];
  // 总账户私钥
  const privateKey = "0x02da90597bf4cef6621103622f27a31d65c0856a0a66ba2fd03e4663161f1c5b";
  let ERC20Token;
  let erc20;
  let TexasHoldem;  // TexasHoldem合约对象
  let game;        // TexasHoldem部署对象
  let admin;
  let player1;
  let player2;
  let player3;
  let player4;
  // token
  const name = "USDT";
  const symbol = "USDT";
  const decimals = 6;
  const totalSupply = 1000000000000000;

  // game
  const smallBlind = 1;
  const bigBlind = 2;
  let tokenAddr;
  let tableId = 0; // 记录tableId
  const transferAmount = totalSupply / 1000;
  const approvalAmount = totalSupply / 100000;
  // const raiseAmount = 2 * bigBlind;  // 加注金额
  const playerNum = 4;

  const PREFLOP = 0; // 游戏结束或未开始
  const FLOP = 1; // 翻牌
  const TURN = 2; // 转牌
  const RIVER = 3; // 河牌
  const FINISH = 4; // 结束（最后一轮的下注）

  // 查看玩家的牌
  async function getPlayerCardInfo(tableId, playerAddr) {
    info = await game.getPlayerInfo(tableId, playerAddr);
    card1 = await game.getNameByCardValue(info.hand[0]);
    card2 = await game.getNameByCardValue(info.hand[1]);
    console.log("       player:",playerAddr, ", get cards:[", card1.cardName, ",", card2.cardName + "]");
  }

  // 等待交易
  async function waitTxList(EventName = "") {
    for (const tx of waitTxs) {
      if(EventName !== "") {
        console.log("EventName:", EventName, ", tx:", tx.hash);
      }
      await tx.wait();
    }
    // 清空交易列表
    waitTxs = [];
  }

  // 获取牌型
  function getCardType(cardType) {
    switch(cardType) {
      case 10:
        return "皇家同花顺";
      case 9:
        return "同花顺";
      case 8:
        return "四条";
      case 7:
        return "满堂红（葫芦）";
      case 6:
        return "同花";
      case 5:
        return "顺子";
      case 4:
        return "三条";
      case 3:
        return "两对";      
      case 2:
        return "一对"; 
      default:
        return "高牌"; 
    }
  }
  // 查看公共的牌
  async function getBoardCardInfo(tableId) {
    info = await game.getTableInfo(tableId);
    logMsg = "       board cards:[";
    let addFlag = false;
    for(i = 0; i < 5; i++) {
      const cardValue = parseInt(info.board[i], 10);
      // console.log(cardValue);
      if(cardValue !== 0) {
        if(addFlag === true) {
          logMsg += ", "
        }
        cardInfo = await game.getNameByCardValue(cardValue);
        logMsg += cardInfo.cardName;
        addFlag = true;
      }
    }
    logMsg += "]";
    console.log(logMsg);
  }

  async function playerAction(tableId, player, action, raiseAmount = 0) {
    if("call" === action) {
      waitTxs.push(await game.call(tableId, player.address));
    } else if("check" === action) {
      waitTxs.push(await game.check(tableId, player.address));
    } else if("raise" === action) {
      waitTxs.push(await game.raise(tableId, player.address, raiseAmount));
    } else if("fold" === action) {
      waitTxs.push(await game.fold(tableId, player.address));
    } 

    if(syncFlag) {
      await waitTxList(action);
    }
    tableInfo = await game.getTableInfo(tableId);
    playerInfo = await game.getPlayerInfo(tableId, player.address);
    // 当前玩家的下注数已达到最高
    expect(tableInfo.highestBet).to.equal(playerInfo.bet);
    if("fold" === action) {
      expect(playerInfo.active).to.equal(false);
    }
  }

  // 参与游戏
  async function joinGame(player) {
    expect((await erc20.balanceOf(player.address))).to.equal(transferAmount);
    // 参与游戏
    waitTxs.push(await game.connect(player).joinGame(approvalAmount));
    if(syncFlag) {
      await waitTxList("joinGame");
    }
    expect((await erc20.balanceOf(player.address))).to.equal(transferAmount - approvalAmount);
  }

  // 转账原生代币(同步模式)
  async function transferNative(toAddrList = []) {
    if(0 === toAddrList.length) {
      return;
    }
    console.log("transferNative===========================");
    if(!syncFlag) return;
    const provider = ethers.provider;
    console.log("provider============:", provider);
    var wallet = new ethers.Wallet(privateKey, provider);
    console.log("wallet============:", wallet);
    const totalBalance = await wallet.getBalance();
    console.log("totalBalance==========:", totalBalance);
    const transferAmount = ethers.utils.parseEther("1");
    if(parseInt(totalBalance, 10) === 0 || parseInt(totalBalance, 10) < transferAmount / toAddrList.length) {
      return;
    }
    // console.log("totalBalance:", parseInt(totalBalance, 10));
    // console.log("transferAmount:", transferAmount);
    for(const addr of toAddrList) {
      const balance = await provider.getBalance(addr);
      // console.log("balance:", balance);
      if(parseInt(balance, 10) === 0) 
      {
        let tx = await wallet.sendTransaction({
          // gasLimit: gasLimit,
          // gasPrice: gasPrice,
          to: addr,
          value: transferAmount
        });
        waitTxs.push(tx);
      }
    }

    await waitTxList("Transfer"); 
  }

  before(async function () {
    for(i = 0; i < asyncNetsFlag.length; i++) {
      // 使用异步方法
      if(network.name === asyncNetsFlag[i]) {
        syncFlag = false;
        break;
      }
    }

    [admin, player1, player2, player3, player4] = await ethers.getSigners();
    // 部署ERC20合约
    ERC20Token = await ethers.getContractFactory("ERC20");
    erc20 = await ERC20Token.deploy(name, symbol, decimals, totalSupply); 
    tokenAddr = erc20.address;

    // 部署TexasHoldem合约
    TexasHoldem = await ethers.getContractFactory("TexasHoldem");
    game = await TexasHoldem.deploy();
    
    // 转原生代币:player1, player2, player3, player4需要原生代币支付交易的手续费
    transferNative([player1.address, player2.address, player3.address, player4.address]);
    // 转token
    waitTxs.push(await erc20.transfer(player1.address, transferAmount));
    waitTxs.push(await erc20.transfer(player2.address, transferAmount));
    waitTxs.push(await erc20.transfer(player3.address, transferAmount));
    waitTxs.push(await erc20.transfer(player4.address, transferAmount));

    // 同步模式
    if(syncFlag) {
      await waitTxList();
    }

    // 授权筹码给游戏合约地址
    waitTxs.push(await erc20.connect(player1).approve(game.address, approvalAmount));
    waitTxs.push(await erc20.connect(player2).approve(game.address, approvalAmount));
    waitTxs.push(await erc20.connect(player3).approve(game.address, approvalAmount));
    waitTxs.push(await erc20.connect(player4).approve(game.address, approvalAmount));
    if(syncFlag) {
      await waitTxList();
    }
  });

  // 创建游戏桌
  describe("CreateTable", function () {
    it("Admin creates game table.", async function () {
      waitTxs.push(await game.createTable(smallBlind, bigBlind, tokenAddr));
      if(syncFlag) {
        console.log("game address:", game.address);
        await waitTxList("CreateTable");
      }
      info = await game.getTableInfo(tableId);
      expect(info.tokenAddr).to.equal(tokenAddr);
    });
  });

  // 玩家参与游戏
  describe("JoinGame", function () {
    it("Player1 Join Game.", async function () {
      await joinGame(player1);
    });

    it("Player2 Join Game.", async function () {
      await joinGame(player2);
    });

    it("Player3 Join Game.", async function () {
      await joinGame(player3);
    });

    it("Player4 Join Game.", async function () {
      await joinGame(player4);
    });

    it("The number of players participating in the game should be 4", async function () {
      info = await game.getTableInfo(tableId);
      expect(info.playerAddrList.length).to.equal(playerNum);
    });
  });

  // 启动游戏
  describe("StartGame", function () {
    it("Admin Start the Game", async function () {
      waitTxs.push(await game.startRound(tableId));
      if(syncFlag) {
        await waitTxList("StartRound");
      }
      
      // 获取玩家将的卡牌
      await getPlayerCardInfo(tableId, player1.address);
      await getPlayerCardInfo(tableId, player2.address);
      await getPlayerCardInfo(tableId, player3.address);
      await getPlayerCardInfo(tableId, player4.address);

      tableInfo = await game.getTableInfo(tableId);
      // console.log("tableInfo:", tableInfo);
      // 游戏状态
      expect(tableInfo.state).to.equal(FLOP);
      expect(tableInfo.dealer).to.equal(0);
      expect(tableInfo.turn).to.equal(3);   // 轮到Player4跟注
    });

    // player4跟注，由amdin地址调用call函数
    it("player4 calls, called by admin address", async function () {
      await playerAction(tableId, player4, "call");
    });

    // player1跟注（庄家位），由amdin地址调用call函数
    it("player1(Dealer position) calls, called by admin address", async function () {
      await playerAction(tableId, player1, "call");
    });

    // player2跟注（小盲注位），由amdin地址调用call函数
    it("player2(small blind position) calls, called by admin address", async function () {
      await playerAction(tableId, player2, "call");
    });

    // player3查牌（大盲注位），由amdin地址调用check函数
    it("player3(big blind position) check cards, called by admin address", async function () {
      await playerAction(tableId, player3, "check");
      // 查看公共牌
      await getBoardCardInfo(tableId);
    });
  });

  // TURN: 转牌轮游戏(加注，跟注轮)
  describe("TURN Round -- raise/call", function () {
    it("The game enters the TURN round.", async function () {
      tableInfo = await game.getTableInfo(tableId);
      expect(tableInfo.state).to.equal(TURN);
      expect(tableInfo.turn).to.equal(3);   // 轮到Player4
    });

    // player4加注，由amdin地址调用raise函数
    it("player4 raises, calls the raise function from the amdin address", async function () {
      raiseAmount = await game.getRaiseAmount(tableId, player4.address);
      // console.log("raiseAmount=====:", raiseAmount);
      await playerAction(tableId, player4, "raise", raiseAmount);
    });

    // player1跟注（庄家位），由amdin地址调用call函数
    it("player1(Dealer position) calls, called by admin address", async function () {
      await playerAction(tableId, player1, "call");
    });

    // player2跟注（小盲注位），由amdin地址调用call函数
    it("player2(small blind position) calls, called by admin address", async function () {
      await playerAction(tableId, player2, "call");
    });

    // player3跟注（大盲注位），由amdin地址调用call函数
    it("player3 calls (big blind position) and calls the call function from the amdin address", async function () {
      await playerAction(tableId, player3, "call");
      // 查看公共牌
      await getBoardCardInfo(tableId);
    });
  });

  // TURN: 转牌轮游戏(查牌轮)
  describe("TURN Round -- check", function () {
    it("The game enters the TURN round.", async function () {
      tableInfo = await game.getTableInfo(tableId);
      expect(tableInfo.state).to.equal(TURN);
      expect(tableInfo.turn).to.equal(3);   // 轮到Player4
    });

    // player4查牌，由amdin地址调用check函数
    it("player4 check card, call check function from amdin address", async function () {
      await playerAction(tableId, player4, "check");
    });
    
    // player1查牌（庄家位），由amdin地址调用check函数
    it("player1(Dealer position) check card, call check function from amdin address", async function () {
      await playerAction(tableId, player1, "check");
    });

    // player2查牌（小盲注位），由amdin地址调用check函数
    it("player2(small blind position) check card, call check function from amdin address", async function () {
      await playerAction(tableId, player2, "check");
    });
  });

  // TURN: 转牌轮游戏
  describe("TURN Round -- fold", function () {
    // player3弃牌（大盲注位），由amdin地址调用fold函数
    it("player3(big blind position) fold card, call fold function from amdin address", async function () {
      await playerAction(tableId, player3, "fold");
      // 查看公共牌
      await getBoardCardInfo(tableId);
    });

    // player4查牌（新的翻牌位），由amdin地址调用check函数
    it("player4(new flop position) check card, call check function from amdin address", async function () {
      await playerAction(tableId, player4, "check");
      // 查看公共牌
      await getBoardCardInfo(tableId);
    });
  });

  // RIVER: 河牌轮游戏
  describe("RIVER Round", function () {
    it("The game enters the RIVER round.", async function () {
      tableInfo = await game.getTableInfo(tableId);
      expect(tableInfo.state).to.equal(RIVER);
    });

    // player1查牌（庄家位），由amdin地址调用check函数
    it("player1(Dealer position) check card, call check function from amdin address", async function () {
      await playerAction(tableId, player1, "check");
    });

    // player2查牌（小盲注位），由amdin地址调用check函数
    it("player2(small blind position) check card, call check function from amdin address", async function () {
      await playerAction(tableId, player2, "check");
    });

    // 跳过player3（已弃牌）操作，player4查牌（新的翻牌位），由amdin地址调用check函数
    it("player4(new flop position) check card, call check function from amdin address", async function () {
      await playerAction(tableId, player4, "check");
      // 查看公共牌
      await getBoardCardInfo(tableId);
    });
  });

  // FINISH: 结束（最后一轮的下注）
  describe("FINISH Round", function () {
    it("The game enters the FINISH round.", async function () {
      tableInfo = await game.getTableInfo(tableId);
      expect(tableInfo.state).to.equal(FINISH);
    });

    // player1查牌（庄家位），由amdin地址调用check函数
    it("player1(Dealer position) check card, call check function from amdin address", async function () {
      await playerAction(tableId, player1, "check");
    });

    // player2查牌（小盲注位），由amdin地址调用check函数
    it("player2(small blind position) check card, call check function from amdin address", async function () {
      await playerAction(tableId, player2, "check");
    });

    // 跳过player3（已弃牌）操作，player4查牌（新的翻牌位），由amdin地址调用check函数
    it("player4(new flop position) check card, call check function from amdin address", async function () {
      // info = await playerAction(tableId, player4, "check");

      // 解析交易回执中的事件
      const provider = ethers.provider;
      txReceipt = await game.check(tableId, player4.address);
      if(syncFlag) {
        waitTxs.push(txReceipt);
        await waitTxList("EndRound");
      }
      // 获取交易回执
      const receipt = await provider.getTransactionReceipt(txReceipt.hash);
      let gameOver = false;
      // 遍历事件日志
      for (const log of receipt.logs) {
        // 判断事件名称
        const logInfo = game.interface.parseLog(log);
        let logMsg = "";
        if (logInfo.name === "Winner") {
          logMsg = "      TableID:" + parseInt(logInfo.args._tableId, 10) + ", Winner Number:" + parseInt(logInfo.args._numWinners, 10) + ", Winner:[ ";
          for(i = 0; i < parseInt(logInfo.args._numWinners, 10); i++) {
            // playerInfo = await game.getPlayerInfo(tableId, logInfo.args._winnerList[i]);
            // logMsg += "player:" + logInfo.args._winnerList[i] + ", strength of cards:" + playerInfo.handRank + "\n";

            logMsg += logInfo.args._winnerList[i] + " ";
          }
          logMsg += "], strength of cards:" + parseInt(logInfo.args._handRank, 10) + ", per winner would revenue:" + parseInt(logInfo.args._revenuePerWinner, 10);
          console.log(logMsg);

        } else if(logInfo.name === "GameOver") {
          // console.log(logInfo);
          gameOver = true;
        }
      }
      
      // 游戏结束
      expect(gameOver).to.equal(true);
    });

    // 获取游戏玩家的最优组合牌
    it("Get the game player's optimal combination of cards", async function () {
      // 获取游戏桌信息
      tableInfo = await game.getTableInfo(tableId);
      let logMsg = "";
      for(i = 0; i < tableInfo.playerAddrList.length; i++) {
        const playerAddr = tableInfo.playerAddrList[i];
        // 获取玩家信息
        playerInfo = await game.getPlayerInfo(tableId, playerAddr);
        // 是否弃牌
        const active = playerInfo.active;
        // 获取组合牌的强弱
        const handRank = parseInt(playerInfo.handRank, 10);
        
        // 获取最优牌
        const bestHand = playerInfo.bestHand;
        logMsg = "      player:" + playerAddr + ", active:" + active + ", bestHand:[ ";
        isAdd = false;
        for(j = 0; j < bestHand.length; j++) {
          if(isAdd) {
            logMsg += ", ";
          }
          const cardValue = parseInt(bestHand[j], 10);
          cardInfo = await game.getNameByCardValue(cardValue);
          // 添加牌
          logMsg += cardInfo.cardName + " ";
          isAdd = true;
        }
        // 牌型说明
        logMsg += "], cardType: " + getCardType(handRank) + "\r\n";
        console.log(logMsg);
      }
      
    });

    // 游戏结束，验证清结算结果
    it("The game is over, and the settlement result is verified and cleared", async function () {
      // 清结算
      tableInfo = await game.getTableInfo(tableId);
      expect(tableInfo.pot).to.equal(0);
      expect(tableInfo.state).to.equal(PREFLOP);
    });
  });


});
