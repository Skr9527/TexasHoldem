const { expect } = require("chai");

describe("TexasHoldem", function () {
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
  let numTable = 0; // 记录tableId
  const transferAmount = totalSupply / 1000;
  const approvalAmount = totalSupply / 100000;
  const raiseAmount = 2 * bigBlind;  // 加注金额
  const playerNum = 4;

  const PREFLOP = 0; // 游戏结束或未开始
  const FLOP = 1; // 翻牌
  const TURN = 2; // 转牌
  const RIVER = 3; // 河牌
  const FINISH = 4; // 结束（最后一轮的下注）

  // 查看玩家的牌
  async function getPlayerCardInfo(numTable, playerAddr) {
    info = await game.getPlayerInfo(numTable, playerAddr);
    card1 = await game.getNameByCardValue(info.hand[0]);
    card2 = await game.getNameByCardValue(info.hand[1]);
    console.log("       player:",playerAddr, ", get cards:[", card1.cardName, ",", card2.cardName + "]");
  }

  // 查看公共的牌
  async function getBoardCardInfo(numTable) {
    info = await game.getTableInfo(numTable);
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

  async function playerAction(numTable, player, action) {
    if("call" === action) {
      await game.call(numTable, player.address);
    } else if("check" === action) {
      await game.check(numTable, player.address);
    } else if("raise" === action) {
      await game.raise(numTable, player.address, raiseAmount);
    } else if("fold" === action) {
      await game.fold(numTable, player.address);
    } 
    
    tableInfo = await game.getTableInfo(numTable);
    playerInfo = await game.getPlayerInfo(numTable, player.address);
    // 当前玩家的下注数已达到最高
    expect(tableInfo.highestBet).to.equal(playerInfo.bet);
    if("fold" === action) {
      expect(playerInfo.active).to.equal(false);
    }
  }

  // 参与游戏
  async function joinGame(numTable, player) {
    expect((await erc20.balanceOf(player.address))).to.equal(transferAmount);
    // 参与游戏
    await game.connect(player).joinGame(numTable, approvalAmount);
    expect((await erc20.balanceOf(player.address))).to.equal(transferAmount - approvalAmount);
  }

  before(async function () {
    [admin, player1, player2, player3, player4] = await ethers.getSigners();
    // 部署ERC20合约
    ERC20Token = await ethers.getContractFactory("ERC20");
    erc20 = await ERC20Token.deploy(name, symbol, decimals, totalSupply); 
    tokenAddr = erc20.address;

    // 部署TexasHoldem合约
    TexasHoldem = await ethers.getContractFactory("TexasHoldem");
    game = await TexasHoldem.deploy();
    
    // 转token
    await erc20.transfer(player1.address, transferAmount);
    await erc20.transfer(player2.address, transferAmount);
    await erc20.transfer(player3.address, transferAmount);
    await erc20.transfer(player4.address, transferAmount);

    // 授权筹码给游戏合约地址
    await erc20.connect(player1).approve(game.address, approvalAmount);
    await erc20.connect(player2).approve(game.address, approvalAmount);
    await erc20.connect(player3).approve(game.address, approvalAmount);
    await erc20.connect(player4).approve(game.address, approvalAmount);
  });

  // 创建游戏桌
  describe("CreateTable", function () {
    it("Admin creates game table.", async function () {
      await game.createTable(smallBlind, bigBlind, tokenAddr);
      info = await game.getTableInfo(numTable);
      expect(info.tokenAddr).to.equal(tokenAddr);
    });
  });

  // 玩家参与游戏
  describe("JoinGame", function () {
    it("Player1 Join Game.", async function () {
      await joinGame(numTable, player1);
    });

    it("Player2 Join Game.", async function () {
      await joinGame(numTable, player2);
    });

    it("Player3 Join Game.", async function () {
      await joinGame(numTable, player3);
    });

    it("Player4 Join Game.", async function () {
      await joinGame(numTable, player4);
    });

    it("The number of players participating in the game should be 4", async function () {
      info = await game.getTableInfo(numTable);
      expect(info.playerAddrList.length).to.equal(playerNum);
    });
  });

  // 启动游戏
  describe("StartGame", function () {
    it("Admin Start the Game", async function () {
      await game.startRound(numTable);
      
      // 获取玩家将的卡牌
      await getPlayerCardInfo(numTable, player1.address);
      await getPlayerCardInfo(numTable, player2.address);
      await getPlayerCardInfo(numTable, player3.address);
      await getPlayerCardInfo(numTable, player4.address);

      tableInfo = await game.getTableInfo(numTable);
      // 游戏状态
      expect(tableInfo.state).to.equal(FLOP);
      expect(tableInfo.dealer).to.equal(0);
      expect(tableInfo.turn).to.equal(3);   // 轮到Player4跟注
    });

    // player4跟注，由amdin地址调用call函数
    it("player4 calls, called by admin address", async function () {
      await playerAction(numTable, player4, "call");
    });

    // player1跟注（庄家位），由amdin地址调用call函数
    it("player1(Dealer position) calls, called by admin address", async function () {
      await playerAction(numTable, player1, "call");
    });

    // player2跟注（小盲注位），由amdin地址调用call函数
    it("player2(small blind position) calls, called by admin address", async function () {
      await playerAction(numTable, player2, "call");
    });

    // player3查牌（大盲注位），由amdin地址调用check函数
    it("player3(big blind position) check cards, called by admin address", async function () {
      await playerAction(numTable, player3, "check");
      // 查看公共牌
      await getBoardCardInfo(numTable);
    });
  });

  // TURN: 转牌轮游戏(加注，跟注轮)
  describe("TURN Round -- raise/call", function () {
    it("The game enters the TURN round.", async function () {
      tableInfo = await game.getTableInfo(numTable);
      expect(tableInfo.state).to.equal(TURN);
      expect(tableInfo.turn).to.equal(3);   // 轮到Player4
    });

    // player4加注，由amdin地址调用raise函数
    it("player4 raises, calls the raise function from the amdin address", async function () {
      await playerAction(numTable, player4, "raise");
    });

    // player1跟注（庄家位），由amdin地址调用call函数
    it("player1(Dealer position) calls, called by admin address", async function () {
      await playerAction(numTable, player1, "call");
    });

    // player2跟注（小盲注位），由amdin地址调用call函数
    it("player2(small blind position) calls, called by admin address", async function () {
      await playerAction(numTable, player2, "call");
    });

    // player3跟注（大盲注位），由amdin地址调用call函数
    it("player3 calls (big blind position) and calls the call function from the amdin address", async function () {
      await playerAction(numTable, player3, "call");
      // 查看公共牌
      await getBoardCardInfo(numTable);
    });
  });

  // TURN: 转牌轮游戏(查牌轮)
  describe("TURN Round -- check", function () {
    it("The game enters the TURN round.", async function () {
      tableInfo = await game.getTableInfo(numTable);
      expect(tableInfo.state).to.equal(TURN);
      expect(tableInfo.turn).to.equal(3);   // 轮到Player4
    });

    // player4查牌，由amdin地址调用check函数
    it("player4 check card, call check function from amdin address", async function () {
      await playerAction(numTable, player4, "check");
    });
    
    // player1查牌（庄家位），由amdin地址调用check函数
    it("player1(Dealer position) check card, call check function from amdin address", async function () {
      await playerAction(numTable, player1, "check");
    });

    // player2查牌（小盲注位），由amdin地址调用check函数
    it("player2(small blind position) check card, call check function from amdin address", async function () {
      await playerAction(numTable, player2, "check");
    });
  });

  // TURN: 转牌轮游戏
  describe("TURN Round -- fold", function () {
    // player3弃牌（大盲注位），由amdin地址调用fold函数
    it("player3(big blind position) fold card, call fold function from amdin address", async function () {
      await playerAction(numTable, player3, "fold");
      // 查看公共牌
      await getBoardCardInfo(numTable);
    });

    // player4查牌（新的翻牌位），由amdin地址调用check函数
    it("player4(new flop position) check card, call check function from amdin address", async function () {
      await playerAction(numTable, player4, "check");
      // 查看公共牌
      await getBoardCardInfo(numTable);
    });
  });

  // RIVER: 河牌轮游戏
  describe("RIVER Round", function () {
    it("The game enters the RIVER round.", async function () {
      tableInfo = await game.getTableInfo(numTable);
      expect(tableInfo.state).to.equal(RIVER);
    });

    // player1查牌（庄家位），由amdin地址调用check函数
    it("player1(Dealer position) check card, call check function from amdin address", async function () {
      await playerAction(numTable, player1, "check");
    });

    // player2查牌（小盲注位），由amdin地址调用check函数
    it("player2(small blind position) check card, call check function from amdin address", async function () {
      await playerAction(numTable, player2, "check");
    });

    // 跳过player3（已弃牌）操作，player4查牌（新的翻牌位），由amdin地址调用check函数
    it("player4(new flop position) check card, call check function from amdin address", async function () {
      await playerAction(numTable, player4, "check");
      // 查看公共牌
      await getBoardCardInfo(numTable);
    });
  });

  // FINISH: 结束（最后一轮的下注）
  describe("FINISH Round", function () {
    it("The game enters the FINISH round.", async function () {
      tableInfo = await game.getTableInfo(numTable);
      expect(tableInfo.state).to.equal(FINISH);
    });

    // player1查牌（庄家位），由amdin地址调用check函数
    it("player1(Dealer position) check card, call check function from amdin address", async function () {
      await playerAction(numTable, player1, "check");
    });

    // player2查牌（小盲注位），由amdin地址调用check函数
    it("player2(small blind position) check card, call check function from amdin address", async function () {
      await playerAction(numTable, player2, "check");
    });

    // 跳过player3（已弃牌）操作，player4查牌（新的翻牌位），由amdin地址调用check函数
    it("player4(new flop position) check card, call check function from amdin address", async function () {
      // info = await playerAction(numTable, player4, "check");

      // 解析交易回执中的事件
      const provider = ethers.provider;
      txReceipt = await game.check(numTable, player4.address);
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
            // playerInfo = await game.getPlayerInfo(numTable, logInfo.args._winnerList[i]);
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
      
      // 清结算
      tableInfo = await game.getTableInfo(numTable);
      expect(tableInfo.pot).to.equal(0);
      expect(tableInfo.state).to.equal(PREFLOP);
      // 游戏结束
      expect(gameOver).to.equal(true);
    });
  });
});
