/**
此游戏合约只用于研究区块链技术使用，不可用于非法的商业用途，否则将追究其法律责任！！！
*/
import "./LibCard.sol";

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TexasHoldem {
    using LibCard for *;
    // 状态常量
    uint8 private constant maxPlayers = 8; // 最大玩家数
    uint256 private constant PREFLOP = 0; // 翻牌前，游戏结束或未启动的标志
    uint256 private constant FLOP = 1; // 翻牌
    uint256 private constant TURN = 2; // 转牌
    uint256 private constant RIVER = 3; // 河牌
    uint256 private constant FINISH = 4; // 结束（最后一轮的下注）

    // 定义一个结构体表示玩家
    struct Player {
        uint256 bet; // 玩家当前下注的筹码数
        uint256 handRank; // 玩家的手牌强弱
        uint256 balance; // 玩家的剩余筹码
        bool active; // 玩家是否已弃牌
        uint256[] hand; // 玩家的手牌
        bool isVaild; // 判断是否存在的标识
    }

    // 定义游戏桌结构体
    struct Table {
        // 定义状态变量
        uint256 id;     // table id
        uint256 state;  // 游戏状态：PREFLOP，FLOP，TURN，RIVER，FINISH
        uint256 dealer; // 庄家的位置
        uint256 smallBlind; // 小盲注的位置
        uint256 bigBlind; // 大盲注的位置
        uint256 bBPos; // 默认大盲注的位置，大盲注弃牌时，则设置为它的下一个玩家的位置，用于判断是否进行对公共牌进行操作：
        uint256 pot; // 奖池
        uint256 highestBet; // 当前轮最高下注数量
        uint256 turn; // 当前操作者的下标
        uint256[] board; // 公共牌
        uint256[] deck; // 52张牌

        // 用于结算的AARC20代币地址
        address tokenAddr;
        // 玩家的地址列表
        address[] playerAddrList;
        // 保存玩家地址的映射关系
        mapping(address => Player) mapPlayer;
    }

    // 定义游戏桌数组
    mapping (uint256 => Table) public tables;
    uint256 public numTable;
    
    /// @notice 创建游戏桌事件
    /// @dev 创建游戏桌事件
    /// @param _tableId 游戏桌ID
    /// @param _smallBlind 小盲注注额
    /// @param _bigBlind 大盲注注额
    /// @param _tokenAddr 清结算ERC20的合约地址
    event CreateTable(uint256 _tableId, uint256 _smallBlind, uint256 _bigBlind, address _tokenAddr);

    /// @notice 玩家参与游戏事件
    /// @dev 玩家参与游戏事件
    /// @param _tableId 游戏桌ID
    /// @param _player 玩家地址
    /// @param _amount 筹码
    event JoinGame(uint256 _tableId, address _player, uint256 _amount);

    /// @notice 新启动一局游戏的事件
    /// @dev 新启动一局游戏的事件
    /// @param _tableId 游戏桌ID
    /// @param _playerAddrList 玩家地址列表
    event StartRound(uint256 _tableId, address[] _playerAddrList);

    /// @notice 玩家Check牌事件
    /// @dev 玩家Check牌事件
    /// @param _tableId 游戏桌ID
    /// @param _player 玩家地址
    event Check(uint256 _tableId, address _player);

    /// @notice 玩家追注时触发事件
    /// @dev 玩家追注时触发事件
    /// @param _tableId 游戏桌ID
    /// @param _player 玩家地址
    /// @param _bet 追注数额
    event Call(uint256 _tableId, address _player, uint256 _bet);

    /// @notice 玩家加注时触发事件
    /// @dev 玩家加注时触发事件
    /// @param _tableId 游戏桌ID
    /// @param _player 玩家地址
    /// @param _raise 加注数额
    /// @param _highestBet 当前最高下注额
    event Raise(uint256 _tableId, address _player, uint256 _raise, uint256 _highestBet);

    /// @notice 当玩家弃牌时触发
    /// @dev 当玩家弃牌时触发
    /// @param _tableId 游戏桌ID
    /// @param _player 玩家地址
    event Fold(uint256 _tableId, address _player);

    /// @notice 结束游戏轮触发事件
    /// @dev 调用endRound接口时触发
    /// @param _tableId 游戏桌ID
    /// @param _round 结束的当前轮：按照游戏状态分为：FLOP，TURN，RIVER，FINISH
    /// @param _board 当前公共牌
    event EndRound(uint256 _tableId, string _round, uint256[] _board);

    /// @notice 游戏结束事件
    /// @dev 重置游戏相关的参数
    /// @param _tableId 游戏桌ID
    event GameOver(uint256 _tableId);

    /// @notice 创建事件：当确定获胜者触发
    /// @dev 创建事件：当确定获胜者触发
    /// @param _tableId 游戏桌ID
    /// @param _numWinners 赢家个数
    /// @param _winnerList 赢家地址列表
    /// @param _handRank 赢家的卡强弱排名: 0：表示除了赢家，其余人都弃牌；1~10:代表不同的强度，以此递增
    /// @param _revenuePerWinner 每个赢家的金额
    event Winner(uint256 _tableId, uint256 _numWinners, address[] _winnerList, uint256 _handRank, uint256 _revenuePerWinner);
    
    // 创建游戏桌
    function createTable(uint256 _smallBlind, uint256 _bigBlind, address _tokenAddr) public {
        require(_smallBlind > 0, "The small blind must be greater than 0.");
        require(_bigBlind > _smallBlind, "The big blind must be greater than the small blind.");

        Table storage table = tables[numTable];
        table.id = numTable;
        table.smallBlind = _smallBlind;
        table.bigBlind = _bigBlind;
        table.tokenAddr = _tokenAddr;
        // 状态变量初始化
        table.dealer = 0;
        table.pot = 0;
        table.state = PREFLOP;
        table.deck = new uint256[](52);
        table.board = new uint256[](5);
        numTable++;
        emit CreateTable(table.id, _smallBlind, _bigBlind, _tokenAddr);
    }
    
    // 构造函数
    constructor() {
        numTable = 0;
    }

    // 是否轮到指定地址执行
    modifier isTurn(uint256 tableId, address addr) {
        Table storage table = tables[tableId];
        require(table.playerAddrList[table.turn] == addr, "It is not the current player's turn to operate.");
        _;
    }

    // 游戏是否正在运行中
    modifier inProcess(uint256 tableId) {
        Table storage table = tables[tableId];
        require(table.state != PREFLOP, "Game didn't start or ended.");
        _;
    }

    // 游戏是否正在运行中
    modifier isStop(uint256 tableId) {
        Table storage table = tables[tableId];
        require(table.state == PREFLOP, "Game is running, not stopped.");
        _;
    }

    // 检查玩家是否处于活跃状态
    modifier isActive(uint256 tableId, address playerAddr) {
        Table storage table = tables[tableId];
        require(table.mapPlayer[playerAddr].active, "Player must be active");
        _;
    }

    // 足够的授权金额
    modifier enoughAllowedTokens(uint256 tableId, address tokenOwner, uint256 amount) {
        Table storage table = tables[tableId];
        uint256 allowedTokens = getTokenAllowance(table.tokenAddr, msg.sender);
        require(allowedTokens >= amount, "Not enough allowed amount.");
        _;
    }

    // 返回调用者授权给合约地址的AARC20的Token余额
    function getTokenAllowance(address tokenAddr, address tokenOwner) internal view returns(uint256 allowedTokens) {
        bytes memory sigData = abi.encodeWithSignature("allowance(address,address)", tokenOwner, address(this));
        (bool isSucceed, bytes memory ret) = tokenAddr.staticcall(sigData);
        require(isSucceed, "Call allowance failed.");
        allowedTokens = uint256(bytes32(ret));
    }

    // 转移一定数量的授权token到合约地址中
    function transferAllowToken(address tokenAddr, address tokenOwner, address to, uint256 amount) internal {
        bytes memory sigData = abi.encodeWithSignature("transferFrom(address,address,uint256)", tokenOwner, to, amount);
        (bool isSucceed, ) = tokenAddr.call(sigData);
        require(isSucceed, "Call transferFrom failed.");
    }
    
    // 玩家参与游戏
    function joinGame(uint256 tableId, uint256 chips) public isStop(tableId) enoughAllowedTokens(tableId, msg.sender, chips) {
        Table storage table = tables[tableId];
        require(table.smallBlind > 0, "Game table not created.");
        require(chips >= table.bigBlind, "Player chips must be greater than the big blind.");
        require(!table.mapPlayer[msg.sender].isVaild, "Player has joined the game.");
        require(table.playerAddrList.length < maxPlayers, "The number of players has exceeded the maximum limit.");
        
        // 转账token到合约地址中
        transferAllowToken(table.tokenAddr, msg.sender, address(this), chips);

        // 保存玩家信息
        Player memory newPlayer;
        newPlayer.isVaild = true;
        // 保存玩家的筹码
        newPlayer.balance = chips;
        newPlayer.active = true;
        table.mapPlayer[msg.sender] = newPlayer;
        table.playerAddrList.push(msg.sender);
        emit JoinGame(tableId, msg.sender, chips);
    }

    function getTableInfo(uint256 tableId) public view 
        returns (
            uint256 state,
            uint256 dealer, // 庄家
            uint256 smallBlind, // 小盲注
            uint256 bigBlind, // 大盲注
            uint256 bBPos, // 大盲注的位置，用于判断是否进行对公共牌进行操作：
            uint256 pot, // 奖池
            uint256 highestBet, // 当前轮最高下注数量
            uint256 turn, // 当前操作者的下标
            address tokenAddr, // token合约地址
            uint256[] memory board, // 公共牌
            address[] memory playerAddrList // 玩家的地址列表
        ) 
    {
        Table storage table = tables[tableId];
        state = table.state;
        dealer = table.dealer;
        smallBlind = table.smallBlind;
        bigBlind = table.bigBlind;
        bBPos = table.bBPos;
        pot = table.pot;
        highestBet = table.highestBet;
        turn = table.turn;
        tokenAddr = table.tokenAddr;
        board = table.board;
        playerAddrList = table.playerAddrList;
    }

    // 获取玩家信息
    function getPlayerInfo(uint256 tableId, address player) public view 
        returns (
            uint256 bet, 
            uint256 handRank, 
            uint256 balance, 
            bool active, 
            uint256[] memory hand) {

        Table storage table = tables[tableId];
        bet = table.mapPlayer[player].bet;
        handRank = table.mapPlayer[player].handRank;
        balance = table.mapPlayer[player].balance;
        active = table.mapPlayer[player].active;
        hand = table.mapPlayer[player].hand;
    }

    // 游戏开始
    function startRound(uint256 tableId) public isStop(tableId) {
        Table storage table = tables[tableId];
        require(table.playerAddrList.length >= 2, "At least two players are required to start the game");
        // 小盲注的地址
        address smallBlindAddr = table.playerAddrList[(table.dealer + 1) % table.playerAddrList.length];
        table.bBPos = (table.dealer + 2) % table.playerAddrList.length;
        // 大盲注的地址
        address bigBlindAddr = table.playerAddrList[table.bBPos];

        require(table.mapPlayer[smallBlindAddr].balance >= table.smallBlind, "The player's remaining chips are less than the small blind's bet");
        require(table.mapPlayer[bigBlindAddr].balance >= table.bigBlind, "The player's remaining chips are less than the big blind's bet");
        
        deal(table); // 发牌
        // 设定初始下注额
        table.mapPlayer[smallBlindAddr].bet = table.smallBlind; // 小盲注
        table.mapPlayer[bigBlindAddr].bet = table.bigBlind; // 大盲注

        // 更新剩余筹码
        table.mapPlayer[smallBlindAddr].balance -= table.smallBlind; // 小盲注
        table.mapPlayer[bigBlindAddr].balance -= table.bigBlind; // 大盲注

        table.pot += table.smallBlind + table.bigBlind; // 更新奖池
        table.highestBet = table.bigBlind; // 设定当前最高下注额为大盲注的数目
        // 更新状态
        table.turn = (table.dealer + 3) % table.playerAddrList.length;
        table.state = FLOP;
        table.board = new uint256[](5);
        // 触发事件
        emit StartRound(tableId, table.playerAddrList);
    }
 
    // 发牌
    function deal(Table storage table) internal {
        // 洗牌
        for (uint256 i = 0; i < table.deck.length; i++) {
            table.deck[i] = i;
        }
        for (uint256 i = table.deck.length - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encodePacked(table.id, block.timestamp, i))) % (i + 1);
            (table.deck[i], table.deck[j]) = (table.deck[j], table.deck[i]);
        }
        // 发牌
        for (uint256 i = 0; i < table.playerAddrList.length; i++) {
            address addr = table.playerAddrList[i];
            // 重置强弱排名为0
            table.mapPlayer[addr].handRank = 0;
            // 玩家获取第一张底牌
            table.mapPlayer[addr].hand.push(table.deck[i]);
            // 玩家获取第二张底牌
            table.mapPlayer[addr].hand.push(table.deck[i + table.playerAddrList.length]);
        }
    }

    // 查牌
    function check(uint256 tableId, address player) public isTurn(tableId, player) inProcess(tableId) isActive(tableId, player) {
        Table storage table = tables[tableId];
        // 检查下注数是否达到当前轮的最高下注数
        require(table.highestBet == table.mapPlayer[player].bet, "The player's bets have not reached the maximum bets of the current round.");

        emit Check(tableId, player);
        // 下一步操作
        nextTurn(table, true);
    }

    // 跟注
    function call(uint256 tableId, address player) public isTurn(tableId, player) inProcess(tableId) isActive(tableId, player) {
        Table storage table = tables[tableId];
        // 检查当前下注额是否高于最高下注数
        require(table.highestBet > table.mapPlayer[player].bet, "The current player's bet amount has reached the current maximum bet amount, Cannot call");
        // 求出需要跟注的数量
        uint256 amount = table.highestBet - table.mapPlayer[player].bet;
        // 更新玩家状态
        table.mapPlayer[player].balance -= amount;
        table.mapPlayer[player].bet += amount;
        table.pot += amount;

        emit Call(tableId, player, amount);
        // 下一步操作
        nextTurn(table, false);
    }
    
    // 加注
    function raise(uint256 tableId, address player, uint256 amount) public isTurn(tableId, player) inProcess(tableId) isActive(tableId, player) {
        Table storage table = tables[tableId];
        // 确认当前加注数量是否高于当前追加的注额
        require(amount > table.highestBet - table.mapPlayer[player].bet, "Bet not high enough");
        // 确认加注数量是否不高于当前余额
        require(amount <= table.mapPlayer[player].balance, "Not enough balance");
        // 更新状态变量
        table.mapPlayer[player].balance -= amount;
        table.highestBet = amount + table.mapPlayer[player].bet;
        table.mapPlayer[player].bet = table.highestBet;
        table.pot += amount;
        
        emit Raise(tableId, player, amount, table.highestBet);
        // 下一步操作
        nextTurn(table, false);
    }
    
    // 弃牌
    function fold(uint256 tableId, address player) public isTurn(tableId, player) inProcess(tableId) isActive(tableId, player) {
        Table storage table = tables[tableId];
        // 将当前玩家的状态设置为“弃牌”，并视作离开游戏
        table.mapPlayer[player].active = false;
        // 如果是大盲注弃牌，更新翻公共牌权限的地址的位置
        if(player == table.playerAddrList[table.bBPos]) {
            // 更新的地址必须是active
            for(uint256 i = 1; i < table.playerAddrList.length; i++) {
                table.bBPos = (table.bBPos + i) % table.playerAddrList.length;
                address bBAddr = table.playerAddrList[table.bBPos];
                if(table.mapPlayer[bBAddr].active) break;
            }
        }
        // 触发事件
        emit Fold(tableId, player);
        // 下一步操作
        nextTurn(table, false);
    }

    // 下一回合
    function nextTurn(Table storage table, bool isCheck) internal {
        // 检查除当前玩家外是否只剩一个活跃的玩家
        uint256 activePlayers = 0;
        address winnerAddr;
        for (uint256 i = 0; i < table.playerAddrList.length; i++) {
            address addr = table.playerAddrList[i];
            if (table.mapPlayer[addr].active) {
                activePlayers++;
                winnerAddr = addr;
            }
        }
        if (activePlayers == 1) {
            // 如果只剩下一个活跃的玩家，那么结束游戏
            table.mapPlayer[winnerAddr].balance += table.pot;
            address[] memory winners = new address[](1);
            winners[0] = winnerAddr;
            // 触发游戏赢家事件
            emit Winner(table.id, 1, winners, 0, table.pot);
            // 重置游戏数据
            resetGame(table);
        } else {
            // turn = (turn + 1) % playerAddrList.length;
            // 判断是否check牌，是否需要翻牌
            if (table.turn == table.bBPos && isCheck) {
                endRound(table);
            }
            // 交换下一个操作者（下一个操作者必须是active）
            uint256 turn = table.turn;
            for (uint256 i = 1; i < table.playerAddrList.length; i++) {
                turn = (table.turn + i) % table.playerAddrList.length;
                address turnAddr = table.playerAddrList[turn];
                if (table.mapPlayer[turnAddr].active) break;
            }
            table.turn = turn;
        }
    }

    // 游戏结束，重置游戏数据
    function resetGame(Table storage table) internal {
        table.state = PREFLOP;    // 公共牌状态, 游戏结束或未启动的标志
        table.pot = 0;         // 资金池
        table.highestBet = 0;  // 最高下注数
        // 更新庄家的位置
        table.dealer = (table.dealer + 1) % table.playerAddrList.length;
        // 把所有手牌和下注清空
        for (uint256 i = 0; i < table.playerAddrList.length; i++) {
            address addr = table.playerAddrList[i];
            table.mapPlayer[addr].bet = 0;
            // table.mapPlayer[addr].handRank = 0;  // 不重置为0，游戏结束后，方便查看, 新一轮游戏开始发牌时，再重置为0；
            table.mapPlayer[addr].active = true;
            table.mapPlayer[addr].hand = new uint256[](0);
        }
        // 重置公共牌(不清空，启动新一轮时设置方便查看)
        // table.board = new uint256[](5);
        // 发布游戏结束的事件
        emit GameOver(table.id);
    }
    
    // 游戏轮结束
    function endRound(Table storage table) internal {
        // 判断当前状态
        if (table.state == FLOP) {
            // 翻牌圈结束
            table.board[0] = table.deck[table.playerAddrList.length * 2 + 1];
            table.board[1] = table.deck[table.playerAddrList.length * 2 + 2];
            table.board[2] = table.deck[table.playerAddrList.length * 2 + 3];
            table.state = TURN;
            // 触发事件
            emit EndRound(table.id, "FLOP", table.board);
        } else if (table.state == TURN) {
            // 转牌圈结束
            table.board[3] = table.deck[table.playerAddrList.length * 2 + 5];
            table.state = RIVER;
            // 触发事件
           emit EndRound(table.id, "TURN", table.board);
        } else if(table.state == RIVER) {
            table.state = FINISH;
            // 河牌圈结束
            table.board[4] = table.deck[table.playerAddrList.length * 2 + 7];
            // 触发事件
           emit EndRound(table.id, "RIVER", table.board);
        } else if(table.state == FINISH) {
            determineWinner(table);
            emit EndRound(table.id, "FINISH", table.board);
            // 结束游戏
            resetGame(table);
        }
    }

    // 确定获胜者
    function determineWinner(Table storage table) internal {
        uint256[] memory handRanks = new uint256[](table.playerAddrList.length);
        for (uint256 i = 0; i < table.playerAddrList.length; i++) {
            address addr = table.playerAddrList[i];
            uint256[] memory allCards = new uint256[](table.board.length + 2);
            allCards[0] = table.mapPlayer[addr].hand[0];
            allCards[1] = table.mapPlayer[addr].hand[1];
            for (uint256 j = 0; j < table.board.length; j++) {
                allCards[j + 2] = table.board[j];
            }
            // 计算玩家的牌的强弱
            handRanks[i] = calculateHandRank(allCards);
            // 保存牌的强弱
            table.mapPlayer[addr].handRank = handRanks[i];
        }
        uint256 highestRank = 0;
        address[] memory winners = new address[](table.playerAddrList.length);
        uint256 numWinners = 0;
        for (uint256 i = 0; i < table.playerAddrList.length; i++) {
            address addr = table.playerAddrList[i];
            if (table.mapPlayer[addr].active) {
                if (handRanks[i] > highestRank) {
                    highestRank = handRanks[i];
                    numWinners = 1;
                    winners[0] = addr;
                } else if (handRanks[i] == highestRank) {
                    winners[numWinners] = addr;
                    numWinners++;
                }
            }
        }
        uint256 winnings = table.pot / numWinners;
        for (uint256 i = 0; i < numWinners; i++) {
            // 清结算
            table.mapPlayer[winners[i]].balance += winnings;
        }
        table.pot = 0;
        emit Winner(table.id, numWinners, winners, table.mapPlayer[winners[0]].handRank, winnings);
    }
    
    // 追加筹码
    function addChips(uint256 tableId, uint256 chips) public enoughAllowedTokens(tableId, msg.sender, chips) {
        Table storage table = tables[tableId];
        require(table.mapPlayer[msg.sender].isVaild, "Sender is not in the game table.");
        require(chips > 0, "Additional chips must be greater than 0");
        // 转账token到合约地址中
        transferAllowToken(table.tokenAddr, msg.sender, address(this), chips);

        table.mapPlayer[msg.sender].balance += chips;
    }
        
    // 玩家兑换筹码为balance
    function exchangeChipsForBalance(uint256 tableId, uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        Table storage table = tables[tableId];
        require(table.mapPlayer[msg.sender].isVaild, "Sender is not in the game table.");
        require(table.mapPlayer[msg.sender].balance >=  amount, "The remaining chips are not enough to exchange Token.");
        
        table.mapPlayer[msg.sender].balance -= amount;
        // 从合约地址中转账token到调用者地址
        bytes memory sigData = abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount);
        (bool isSucceed, ) = table.tokenAddr.call(sigData);
        require(isSucceed, "Call transfer failed"); 
    }

    // 查看自己的手牌
    // function viewHand(uint256 tableId, address addr) public view returns (uint256[2] memory) {
    //     Table storage table = tables[tableId];
    //     uint256[2] memory hand;
    //     hand[0] = table.mapPlayer[addr].hand[0];
    //     hand[1] = table.mapPlayer[addr].hand[1];
    //     return hand;
    // }
    
    // 根据牌值返回牌的花色和点数
    function getNameByCardValue(uint256 card) pure public returns (uint256 suit, uint256 rank, string memory cardName) {
        return LibCard.getNameByCardValue(card);
    }

    // 计算玩家的手牌排名
    function calculateHandRank(uint256[] memory cards) pure internal returns (uint256) {
        return LibCard.calculateHandRank(cards);
    }
}
