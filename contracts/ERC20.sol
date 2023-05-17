// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
/**
ERC20代币合约标准接口定义
*/
interface IERC20 {
    // 声明事件
    // 从_from向_to转账
    event Transfer(address indexed _from, address indexed _to, uint _value);
    // 允许_spender从_owner中使用_value数量的代币
    event Approval(address indexed _owner, address indexed _spender, uint _value);
    
    // 声明函数(可选)
    // 返回代币名字
    function name() external view returns(string memory);
    // 返回代币的简称
    function symbol() external view returns(string memory);
    // 返回代币小数点后面几位数(精确到小数点后面几位)
    function decimals() external view returns(uint8);

    // 声明函数(必选)
    // 返回代币总量
    function totalSupply() external view returns(uint);
    // 返回指定账户的余额
    function balanceOf(address _addr) external view returns(uint);
    // 从合约调用者地址上转移数量为_amount的代币到_to地址上
    function transfer(address _to, uint _amount) external returns(bool);
    // 从_from地址转移数量为_amount的代币到_to地址上
    function transferFrom(address _from, address _to, uint _amount) external returns(bool);
    // 同意_spender地址从合约调用者上获取数量为_amount代币的处置权(可分多次，由合约调用者代为处置)
    function approve(address _spender, uint _amount) external returns(bool);
    // 查询_spender地址在_owner上还剩余多少代币的处置权
    function allowance(address _owner, address _spender) external view returns(uint);
}

/// @title ERC20Token
/// @notice 遵循ERC20代币标准的合约实现
contract ERC20 is IERC20 {
    string name_;
    string symbol_;
    uint8 decimals_;
    // 保存代币总发行量
    uint totalSupply_;
    // 保存地址和金额的映射关系
    mapping(address => uint) balances;
    /* 
        保存地址上的金额被允许花费的地址的映射关系:
    */
    mapping(address => mapping(address => uint)) allowed;

    // 构造函数不能重载
    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint _totalSupply) {
        name_ = _name;
        symbol_ = _symbol;
        decimals_ = _decimals;
        totalSupply_ = _totalSupply;
        balances[msg.sender] = totalSupply_;   // 一次性发行所有数量的代币
        emit Transfer(address(0), msg.sender, totalSupply_);
    }

    // 返回代币名字
    function name() external view override returns(string memory) {
        return name_;
    }

    // 返回代币的简称
    function symbol() external view override returns(string memory) {
        return symbol_;
    }
    // 返回代币小数点后面几位数(精确到小数点后面几位)
    function decimals() external view override returns(uint8) {
        return decimals_;
    }

    // 返回代币总量
    function totalSupply() public view override returns(uint) {
        return totalSupply_;
    }
    // 返回指定账户的余额
    function balanceOf(address _addr) public view override returns(uint) {
        return balances[_addr];
    }

    // 函数修改器：校验金额是否足够转账
    modifier enoughBalance(address _from, uint _amount) {
        require(balances[_from] >= _amount, "Have not enough balance.");
        _;
    }

    // 从合约调用者地址上转移数量为_amount的代币到_to地址上（发送合约调用者余额）
    function transfer(address _to, uint _amount) external enoughBalance(msg.sender, _amount) override returns(bool) {
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
        emit Transfer(msg.sender, _to, _amount);
        return true;
    }

    // 将_from地址中允许合约调用者花费的部分金额转移数量为_amount代币到_to地址上（发送合约调用者的余量）
    function transferFrom(address _from, address _to, uint _amount) external enoughBalance(_from, _amount) override returns(bool) {
        require(allowed[_from][msg.sender] >= _amount, "The amount allowed to be used");
        // 从拥有者中扣除转账金额
        balances[_from] -= _amount;
        // 接收者增加金额
        balances[_to] += _amount;
        // 重新计算合约调用者可使用的托管在_from地址的金额
        allowed[_from][msg.sender] -= _amount;
        emit Transfer(_from, _to, _amount);
        return true;
    }
     
    // 同意_spender地址从合约调用者上获取数量为_amount代币的处置权(可分多次，由合约调用者代为处置)
    function approve(address _spender, uint _amount) external enoughBalance(msg.sender, _amount) override returns(bool) {
        // 授权使用的金额不叠加，重新覆盖原来的授权额度
        allowed[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    // 查询_spender地址在_owner上还剩余多少代币的处置权
    function allowance(address _owner, address _spender) external view override returns(uint) {
        return allowed[_owner][_spender];
    }
}
