pragma solidity ^0.4.24;

import "https://github.com/eoshackathon/multi-stage-ico/solidity/ERC20Interface.sol";
import "https://github.com/eoshackathon/multi-stage-ico/solidity/SafeMath.sol";
import "https://github.com/eoshackathon/multi-stage-ico/solidity/Owned.sol";
import "https://github.com/eoshackathon/multi-stage-ico/solidity/StringTools.sol";

contract MultiStageToken is ERC20Interface, StringTools, Owned {
    using SafeMath for uint;

    string public symbol;               //Symbol of Token
    string public  name;                //Name of Token
    uint8 public decimals;              //decimals of Token
    uint public _totalSupply;           //totalSupply of Token

    mapping(address => uint) balances;  
    mapping(address => mapping(address => uint)) allowed;

    struct StageTime {                 //Set the time of each stage.
        uint32 saleStartTime;
        uint32 saleEndTime;
        uint32 lockStartTime;
        uint32 lockEndTime;
        uint32 voteStartTime;
        uint32 voteEndTime;
    }
    
    struct VoteData {
        uint8 targetVoteRate;
        uint8 targetAgreeRate;
        uint8 currentVoteRate;
        uint8 currentAgreeRate;
        uint256 currentInvestors;
        uint256 currentAgreeVotes;
        uint256 currentOpposeVotes;
    }
    
    struct Stage{
        //期数
        uint256 totalAmount;            //Total amount of ethereum (Wei) for this stage
        uint256 raisedAmount;           //Raised amount of ethereum (Wei) for this stage
        uint256 balanceAmount;          //Balance amount of ethereum (Wei) for this stage
        uint256 changeRate;             //How many tokens for 1 eth
        uint256 minWei;                 //Minimum ethereum (Wei) to invest for this stage
        uint256 maxWei;                 //Maximum ethereum (Wei) to invest for this stage

        bool  actived;                  //Current stage is actived
        bool  isSaling;                 //正在销售中，未满额
        bool  isRevealed;               //是否已经唱票
        bool  isPass;                   //是否投票通过

        uint8 returnBackCommission;     //如果投票失败，退还ETH时的折扣

        StageTime time;
        VoteData vote;
    }
    
    struct Investor {
        //投资人
        address investor;       //投资人地址
        uint8 periodId;         //分期批次

        uint256 ethAmount;      //投的eth数量
        uint256 tokens;         //Token
        uint8 voteStatus;       //投票结果 0-未投票，1-赞成, 2-反对
    }
    
    Stage[] public steps;
    Investor[] public investors;

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    constructor() public {
        symbol = "GUQ";
        name = "GU QIANFENG";
        decimals = 18;
        _totalSupply = 100000000 * 10**uint(decimals);
        balances[owner] = _totalSupply;
        //emit Transfer(address(0), owner, _totalSupply);

        //测试数据
        Stage  memory period_1;
        period_1.totalAmount = 5000 * 10**uint(decimals);      //5000以太坊
        period_1.raisedAmount = 0;
        period_1.balanceAmount = 0;
        period_1.changeRate = 10000;                          //1:10000
        period_1.minWei = 1 * 10**uint(decimals - 2);       //0.01个eth
        period_1.maxWei = 100 * 10**uint(decimals);
        period_1.actived = true;
        period_1.isSaling = true;
        period_1.time.saleStartTime = 1532390400;                //2018-7-24 08:00:00
        period_1.time.saleEndTime = 1532908800;                  //2018-7-30 8:00:00
        period_1.time.lockStartTime = 1532908800;                //
        period_1.time.lockEndTime = 1535587200;                  //2018-10-30 8:00:00 开始解锁
        period_1.time.voteStartTime = 1535587200;                //本轮投票时间
        period_1.time.voteEndTime = 1535932800;                  //投票结束时间
        period_1.vote.targetVoteRate = 30;                             //至少30%的投票率
        period_1.vote.targetAgreeRate = 40;                           //反对票超过60%则取消
        period_1.isRevealed = false;
        period_1.isPass = false;
        period_1.returnBackCommission = 1;                  //扣除1%费用
        steps.push(period_1);
        
        Stage  memory period_2;
        period_2.totalAmount = 3000 * 10 **uint(decimals);      //5000以太坊
        period_2.raisedAmount = 0;
        period_2.balanceAmount = 0;
        period_2.changeRate = 8000;                           //1:8000
        period_2.minWei = 1 * 10**uint(decimals - 2);       //0.01个eth
        period_2.maxWei = 100 * 10**uint(decimals);
        period_2.actived = true;
        period_2.isSaling = true;
        period_2.time.saleStartTime = 1541289600;                //2018-11-4 08:00:00
        period_2.time.saleEndTime = 1541808000;                  //2018-11-10 8:00:00
        period_2.time.lockStartTime = 1541808000;                //
        period_2.time.lockEndTime = 1544400000;                  //2018-12-10 8:00:00 开始解锁
        period_2.time.voteStartTime = 1544400000;                //本轮投票时间
        period_2.time.voteEndTime = 1544832000;                  //投票结束时间
        period_2.vote.targetVoteRate = 30;
        period_2.vote.targetAgreeRate = 45;                           //反对票超过60%则取消
        period_2.isRevealed = false;
        period_2.isPass = false;
        period_2.returnBackCommission = 5;                  //扣除1%费用
        steps.push(period_2);
    }
    
    function verifyParams() public view returns(bool) {
        //检验输入的参数，是否符合要求
        if(steps.length >= 30) return false;

        bool re = true;
        uint256 _totalAmount = 0;
        
        for(uint8 i = 0; i < steps.length; i++ ){
            _totalAmount = _totalAmount + steps[i].totalAmount * steps[i].changeRate;
        }
        if (_totalAmount > _totalSupply) re = re && false;
        
        for(i = 0; i < steps.length; i++ ){
            if(steps[i].vote.targetAgreeRate > 100 || steps[i].vote.targetAgreeRate < 0) {
                re = re && false;
                break;
            }
            /*
            if(steps[i].returnBackCommission > 100 || steps[i].returnBackCommission < 0) {
                re = re && false;
                break;
            }
            */
            if(steps[i].changeRate < 0) {
                re = re && false;
                break;
            }
            if(!(steps[i].time.saleEndTime >= steps[i].time.saleStartTime && steps[i].time.lockStartTime >= steps[i].time.saleEndTime 
                && steps[i].time.lockEndTime >= steps[i].time.lockStartTime && steps[i].time.voteStartTime >= steps[i].time.lockEndTime
                && steps[i].time.voteEndTime >= steps[i].time.voteStartTime)) {
                re = re && false;
                break;
            }
            if(i > 0 && steps[i].time.saleStartTime < steps[i - 1].time.voteEndTime) {
                re = re && false;
                break;
            }
        }
        return re;
    }
    
    function invest() public payable returns(uint8) {
        /**
         * 100 - 初始状态
         * 101 - 不在Token销售时间内
         * 102 - 金额不在规定范围内
         * 103 - 达到硬顶，将余额打回
         * 104 - 投资人补投成功
         * 105 - 投资人新投成功
         */
        require(msg.value > 0); //判断ETH金额是否大于0
        require(steps.length < 30 && steps.length > 0);
        //首先判断时间，处于哪个阶段，是否接受打币
        uint8 periodId = 30;
        for(uint8 i = 0; i < steps.length; i++) {
            if(now <= steps[i].time.saleEndTime && now >= steps[i].time.saleStartTime && steps[i].actived && steps[i].isSaling) {
                //判断当前时间是否在
                periodId = i;
                break;
            }
        }
        if(periodId == 30) {
            msg.sender.transfer(msg.value);                                 //如果没有合适的时间，则退回
            return(101);
        } else {
            //开始处理投资
            Stage memory p = steps[periodId];
            if(msg.value >= p.minWei && msg.value <= p.maxWei) {
                if(p.raisedAmount < p.totalAmount) {
                    uint256 valueNeed = msg.value;
                    p.raisedAmount = p.raisedAmount.add(msg.value);
                    p.balanceAmount = p.balanceAmount.add(msg.value);
                    if(p.raisedAmount > p.totalAmount) {
                        uint256 valueLeft = p.raisedAmount.sub(p.totalAmount);
                        valueNeed = msg.value.sub(valueLeft);
                        msg.sender.transfer(valueLeft);
                        p.raisedAmount = p.totalAmount;
                        p.balanceAmount = p.totalAmount;
                    }
                    if(p.raisedAmount >= p.totalAmount) {
                        p.isSaling = false;
                    }
                    uint256 tokenValue = valueNeed.mul(p.changeRate);
                    
                    balances[owner] = balances[owner].sub(tokenValue);      //总的余额减少
                    
                    //查找investors数组中是否有记录
                    Investor memory inv;
                    bool foundInvestor = false;
                    for(uint256 j = 0; j < investors.length; j++) {
                        if(investors[j].investor == msg.sender && investors[j].periodId == periodId) {
                            //在同一轮，第二次增投
                            inv = investors[j];
                            inv.ethAmount += valueNeed;
                            inv.tokens += tokenValue;
                            foundInvestor = true;
                            break;
                        }
                    }
                    if(!foundInvestor) {
                        inv.investor = msg.sender;
                        inv.periodId = periodId;
                        inv.ethAmount = valueNeed;
                        //inv.frozenToken = tokenValue;
                        inv.tokens = 0;
                        inv.voteStatus = 0;
                        investors.push(inv);
                        return(105);
                    } else {
                        return(104);
                    }
                    //emit Transfer(owner, msg.sender, tokenValue);
                }
            } else {
                //金额不在规定范围内
                msg.sender.transfer(msg.value);
                return(102);
            }  
        }
    }

    function getPeriodData() public view returns(string) {
        string memory s = "";
        if(steps.length > 0) {
            for(uint8 i = 0; i < steps.length; i++) {
                s = concat(s, uintToString(steps[i].totalAmount));
                s = concat(s, ", ");
                s = concat(s, uintToString(steps[i].raisedAmount));
            }
        }
        return s;
    }
    
    /*
    function getInvestorData() public view returns(string) {
        string memory s = "";
        if(investors.length > 0) {
            for(uint8 i = 0; i < investors.length; i++) {
                s = concat(s, addressToString(investors[i].investor));
                s = concat(s, ", ");
                s = concat(s, uintToString(investors[i].periodId));
                s = concat(s, ", ");
                s = concat(s, uintToString(investors[i].frozenToken));
                s = concat(s, "| ");
            }
        }
        return s;
    }
    */
    
    function getFrozenToken() public view returns(uint8) {
        return investors[0].periodId; //****** 测试
    }
    
    function withdrawTokenForStep(uint8 step) public payable returns(uint8, uint256) {
        //从某一阶段中提现已经解冻的代币
        /**
         * 返回值
         * 100 - 成功
         * 101 - 用户不存在
         * 102 - 用户存在，但是没有已经解冻的
         * 103 - 该轮投票还没结束
         * 104 - 用户在操作本步骤时打了eth
         */
        require(step >= 0 && step <= steps.length);
        require(steps.length < 30 && steps.length > 0);
        
        if(msg.value > 0) {
            //如果用户不慎打了eth，则原路返回
            msg.sender.transfer(msg.value);
            return(104, msg.value);
        }
        
        //检验该阶段投票是否结束，投票结果是否通过
        if(steps[step].isPass) {
            //检测该用户是否存在于该阶段中
            var (has, id) = getInvestorId(msg.sender, step);

            if(has) {
                uint256 freeToken = investors[id].tokens;
                if(freeToken > 0) {
                    balances[msg.sender] += freeToken; //提取代币
                    return(100, freeToken);
                } else {
                    return(102, 0);
                }
            } else {
                return(101, 0);
            }
        } else {
            return(103, 0);
        }
    }
    
    function withdrawAllToken() public payable returns(uint8, uint256) {
        //从所有未提的已经解冻的Token提取
        /**
         * 返回值
         * 100 - 成功
         * 104 - 用户在操作本步骤时打了eth
         */
        require(steps.length < 30 && steps.length > 0);
        
        if(msg.value > 0) {
            //如果用户不慎打了eth，则原路返回
            msg.sender.transfer(msg.value);
            return(104, msg.value);
        }
        
        //检验该阶段投票是否结束，投票结果是否通过
        uint256 totalWithdrawTokens = 0;
        for(uint8 step = 0; step < steps.length; step++) {
            if(steps[step].isPass) {
                //检测该用户是否存在于该阶段中
                var (has, id) = getInvestorId(msg.sender, step);

                if(has) {
                    uint256 freeToken = investors[id].tokens;
                    if(freeToken > 0) {
                        totalWithdrawTokens += freeToken;
                    }
                }
            }            
        }
        balances[msg.sender] += totalWithdrawTokens;
        return(100, totalWithdrawTokens);
    }
    
    function checkBalanceEthForStep(uint8 step) public view returns(uint256) {
        //返回某一阶段已经解锁的金额
        require(step >= 0 && step <= steps.length);
        require(steps.length < 30 && steps.length > 0);
        
        return steps[step].balanceAmount;
    }
    
    function checkRaisedEthForStep(uint8 step) public view returns(uint256) {
        //返回某一阶段已经众筹的ETH
        require(step >= 0 && step <= steps.length);
        require(steps.length < 30 && steps.length > 0);
        
        return steps[step].raisedAmount;
    }
    
    function checkIsPassed(uint8 step) public view returns(bool) {
        //返回某一阶段是否已经通过投票
        require(step >= 0 && step <= steps.length);
        require(steps.length < 30 && steps.length > 0);
        
        return steps[step].isPass;
    } 
    
    function withdrawEthForStep(uint8 step, uint256 amount) public onlyOwner payable returns(uint8, uint256) {
        //合约主人提取已经解冻的以太坊
        /**
         * 返回值
         * 100 - 成功
         * 101 - 用户不存在
         * 102 - 余额不够
         * 103 - 该轮投票还没通过
         * 104 - 用户在操作本步骤时打了eth
         */
        require(step >= 0 && step <= steps.length);
        require(steps.length < 30 && steps.length > 0);
        require(amount > 0);
        
        if(msg.value > 0) {
            //如果合约所有人不慎打了eth，则原路返回
            msg.sender.transfer(msg.value);
            return(104, msg.value);
        }
        
        //检验该阶段投票是否结束，投票结果是否通过
        if(steps[step].isPass) {
            if(amount > steps[step].balanceAmount) {
                return(102, amount);
            } else {
                msg.sender.transfer(amount);
                steps[step].balanceAmount -= amount;
                return(100, amount);
            }
        } else {
            return(103, 0);
        }
    }
    
    function stopICO() public onlyOwner payable {
        //终止ICO，全部退回ETH
        uint256 totalEthAmount = 0;
        for(uint8 i = 0; i < steps.length; i++) {
            Stage memory s = steps[i];
            s.actived = false;
            s.isSaling = false;
            s.isPass = false;
            totalEthAmount += s.balanceAmount;
            s.balanceAmount = 0;
        }
        msg.sender.transfer(totalEthAmount);
    }
    
    function vote(uint8 isAggree) public payable returns(uint8, uint8) {
        //投票
        //100 - 成功投票
        //101 - 参数不正确，1为同意，2为否决
        //102 - 不在投票时间段，或者该阶段已经被取消
        //103 - 该投票用户没有参与投资
        //104 - 已经投过票，不能重复投票
        //105 - 投赞成票
        //106 - 投反对票，已将代币清除，并将以太坊返还
        //首先判断时间，处于哪个阶段
        uint8 periodId = 30;
        for(uint8 i = 0; i < steps.length; i++) {
            if(now <= steps[i].time.voteEndTime && now >= steps[i].time.voteStartTime && steps[i].actived) {
                //判断当前时间是否在
                periodId = i;
                break;
            }
        }
        
        if(periodId < 30) {
            var (hasInvested, id) = getInvestorId(msg.sender, periodId);

            if(hasInvested) {
                if(investors[id].voteStatus == 0) {
                    if(isAggree == 1 || isAggree == 2) {
                        investors[id].voteStatus = isAggree;
                        
                        //Change the vote tatus
                        changeVoteStatus(periodId);
                        if(isAggree == 2) {
                            //立即将ETH返回给投反对票的人
                            balances[owner] += investors[id].tokens;
                            investors[id].tokens = 0;
                            msg.sender.transfer(investors[id].ethAmount);
                            return(106, periodId);
                        } else {
                            return(105, periodId);
                        }
                    } else return(101, periodId);
                } else {
                    return(104, periodId);
                }
            } else {
                return (103, periodId);
            }
        } else {
            return(102, periodId);
        }
    }
    
    function checkVoteFinish() public view returns(bool) {
        //检查投票是否结束
        //******
        /*
        var (periodId, voteRate, agreeRate, totalInvestors, agreeVotes, opposeVotes) = checkVote();        
        if(periodId == 0 && voteRate == 0) {
            return(false);
        } else {
            
        }
        */
        //steps[periodId].isRevealed = true;//唱票结束
    }
    
    function changeVoteStatus(uint8 periodId) private {
        //查看当前投票情况
        //0,0 - 时间不对
        //前面是投票率，后面是赞成票比例，都是四位数，万分之几
        //统计投票人次以及投票结果
        uint256 totalInvestors = 0;
        uint256 agreeVotes = 0;
        uint256 opposeVotes = 0;
        for(uint256 j = 0; j < investors.length; j++) {
            Investor memory inv;
            if(inv.periodId == periodId) {
                totalInvestors++;
                if(inv.voteStatus == 1) agreeVotes++;
                else if(inv.voteStatus == 2) opposeVotes++;
            }
        }
        
        //计算投票率和票数结果
        uint256 voteRate = (agreeVotes + opposeVotes) * 10000 / totalInvestors; //是四位数，以精确到小数点后2位
        uint256 agreeRate = opposeVotes * 10000 / totalInvestors;//赞同票数的比例
        
        steps[periodId].vote.currentInvestors = totalInvestors;
        steps[periodId].vote.currentAgreeVotes = agreeVotes;
        steps[periodId].vote.currentOpposeVotes = opposeVotes;
        steps[periodId].vote.currentVoteRate = uint8(voteRate);
        steps[periodId].vote.currentAgreeRate = uint8(agreeRate);
    }
    
    function getInvestorId(address user, uint8 periodId) private view returns(bool, uint256) {
        bool hasInvested = false;
        uint256 id = 0;
        for(uint256 j = 0; j < investors.length; j++) {
            if(investors[j].investor == user && investors[j].periodId == periodId) {
                hasInvested = true;
                id = j;
                break;
            }
        }
        return(hasInvested, id);
    }
    
    // ------------------------------------------------------------------------
    // Total supply
    // ------------------------------------------------------------------------
    function totalSupply() public view returns (uint) {
        return _totalSupply.sub(balances[address(0)]);
    }

    // ------------------------------------------------------------------------
    // Get the token balance for account `tokenOwner`
    // ------------------------------------------------------------------------
    function balanceOf(address tokenOwner) public view returns (uint balance) {
        return balances[tokenOwner];
    }

    // ------------------------------------------------------------------------
    // Transfer the balance from token owner's account to `to` account
    // - Owner's account must have sufficient balance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transfer(address to, uint tokens) public returns (bool success) {
        balances[msg.sender] = balances[msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    // ------------------------------------------------------------------------
    // Token owner can approve for `spender` to transferFrom(...) `tokens`
    // from the token owner's account
    //
    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
    // recommends that there are no checks for the approval double-spend attack
    // as this should be implemented in user interfaces 
    // ------------------------------------------------------------------------
    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    // ------------------------------------------------------------------------
    // Transfer `tokens` from the `from` account to the `to` account
    // 
    // The calling account must already have sufficient tokens approve(...)-d
    // for spending from the `from` account and
    // - From account must have sufficient balance to transfer
    // - Spender must have sufficient allowance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        balances[from] = balances[from].sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        emit Transfer(from, to, tokens);
        return true;
    }

    // ------------------------------------------------------------------------
    // Returns the amount of tokens approved by the owner that can be
    // transferred to the spender's account
    // ------------------------------------------------------------------------
    function allowance(address tokenOwner, address spender) public view returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }


    // ------------------------------------------------------------------------
    // Token owner can approve for `spender` to transferFrom(...) `tokens`
    // from the token owner's account. The `spender` contract function
    // `receiveApproval(...)` is then executed
    // ------------------------------------------------------------------------
    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        ApproveAndCallFallBack(spender).receiveApproval(msg.sender, tokens, this, data);
        return true;
    }

    // ------------------------------------------------------------------------
    // Owner can transfer out any accidentally sent ERC20 tokens
    // ------------------------------------------------------------------------
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
}
