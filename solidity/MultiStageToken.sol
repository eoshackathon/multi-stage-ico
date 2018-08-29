pragma solidity ^0.4.24;

/**
 * 
 * Writen by Jacky Gu@BTCMedia
 * Copyright 2018-2020
 * You can contact with me on wechat: guqianfeng001 or email: jackygu2006@163.com
 * 
 * LET'S CHANGE THE WORLD!
 */

import "https://github.com/eoshackathon/multi-stage-ico/solidity/ERC20Interface.sol";
import "https://github.com/eoshackathon/multi-stage-ico/solidity/SafeMath.sol";
import "https://github.com/eoshackathon/multi-stage-ico/solidity/Owned.sol";

contract MultiStageToken is ERC20Interface, Owned {
    using SafeMath for uint;

    string  public      symbol;                 //Symbol of Token
    string  public      name;                   //Name of Token
    uint8   public      decimals;               //decimals of Token
    uint    public      _totalSupply;           //totalSupply of Token

    mapping(address => uint) balances;  
    mapping(address => mapping(address => uint)) allowed;

    struct StageTime {                          //Set the time of each stage.
        uint32 saleStartTime;
        uint32 saleEndTime;
        uint32 lockStartTime;
        uint32 lockEndTime;
        uint32 voteStartTime;
        uint32 voteEndTime;
    }
    
    struct VoteData {
        bool  amountWeighting;
        uint256 targetVoteRate;
        uint256 targetAgreeRate;
        uint256 currentVoteRate;
        uint256 currentAgreeRate;
        uint256 currentInvestors;
        uint256 currentAgreeVotes;
        uint256 currentOpposeVotes;
    }
    
    struct Stage{
        uint256 totalAmount;                    //Total amount of ethereum (Wei) for this stage
        uint256 raisedAmount;                   //Raised amount of ethereum (Wei) for this stage
        uint256 balanceAmount;                  //Balance amount of ethereum (Wei) for this stage
        uint256 changeRate;                     //How many tokens for 1 eth
        uint256 minWei;                         //Minimum ethereum (Wei) to invest for this stage
        uint256 maxWei;                         //Maximum ethereum (Wei) to invest for this stage
        uint8   refundDiscount;                 //If vote result is stop ico, deduce this percent than return back to investors

        bool  actived;                          //Current stage is actived
        bool  isPass;                           //If the vote for agree more than oppose, set to true.

        StageTime time;
        VoteData vote;
    }
    
    struct Investor {
        //投资人
        address investor;                       //Investor's address
        uint8 stageId;                          //Which stage

        uint256 ethAmount;                      //Amount of eth
        uint256 tokens;                         //Amount of token
        uint8 voteStatus;                       //Vote status, 0-not vote, 1-agree, 2-oppose
    }
    
    Stage[] public stages;
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

        //Config Data
        Stage  memory period_1;
        period_1.totalAmount = 50 * 10**uint(decimals);
        period_1.raisedAmount = 0;
        period_1.balanceAmount = 0;
        period_1.changeRate = 10000;                     
        period_1.minWei = 1 * 10**uint(decimals - 2);    
        period_1.maxWei = 100 * 10**uint(decimals);
        period_1.actived = true;
        
        period_1.time.saleStartTime = 1535558400;
        period_1.time.saleEndTime = 1535560200;
        period_1.time.lockStartTime = 1535560200;
        period_1.time.lockEndTime = 1535560200;
        period_1.time.voteStartTime = 1535560200;
        period_1.time.voteEndTime = 1535563800;

        period_1.vote.amountWeighting = false;
        period_1.vote.targetVoteRate = 30;
        period_1.vote.targetAgreeRate = 40;
        period_1.isPass = false;
        period_1.refundDiscount = 1;            
        stages.push(period_1);
        
        Stage  memory period_2;
        period_2.totalAmount = 300 * 10 **uint(decimals);
        period_2.raisedAmount = 0;
        period_2.balanceAmount = 0;
        period_2.changeRate = 8000;
        period_2.minWei = 1 * 10**uint(decimals - 2);
        period_2.maxWei = 100 * 10**uint(decimals);
        period_2.actived = true;
        
        period_2.time.saleStartTime = 1535538900;
        period_2.time.saleEndTime = 1535539500;
        period_2.time.lockStartTime = 1535544000;
        period_2.time.lockEndTime = 1535544000;
        period_2.time.voteStartTime = 1535547600;
        period_2.time.voteEndTime = 1535634000;

        period_2.vote.amountWeighting = false;
        period_2.vote.targetVoteRate = 30;
        period_2.vote.targetAgreeRate = 45;          
        period_2.isPass = false;
        period_2.refundDiscount = 5;
        stages.push(period_2);
    }
    
    function verifyParams() public view returns(bool, uint8) {
        //Verify config data
        if(stages.length >= 30 || stages.length == 0) return(false, 1);

        uint256 _totalAmount = 0;
        
        for(uint8 i = 0; i < stages.length; i++ ){
            _totalAmount = _totalAmount.add(stages[i].totalAmount);
        }
        if (_totalAmount > _totalSupply) return(false, 2);
        
        for(i = 0; i < stages.length; i++ ){
            if(stages[i].vote.targetAgreeRate > 100 || stages[i].vote.targetAgreeRate < 0) {
                return(false, 3);
            }
            if(stages[i].refundDiscount > 100 || stages[i].refundDiscount < 0) {
                return(false, 4);
            }
            if(stages[i].changeRate < 0) {
                return(false, 5);
            }
            if(stages[i].minWei < 0 || stages[i].maxWei < 0 || stages[i].minWei > stages[i].maxWei) {
                return(false, 6);
            }
            if(!(stages[i].time.saleEndTime >= stages[i].time.saleStartTime && stages[i].time.lockStartTime >= stages[i].time.saleEndTime 
                && stages[i].time.lockEndTime >= stages[i].time.lockStartTime && stages[i].time.voteStartTime >= stages[i].time.lockEndTime
                && stages[i].time.voteEndTime >= stages[i].time.voteStartTime)) {
                return(false, 7);
            }
            if(i > 0 && stages[i].time.saleStartTime < stages[i - 1].time.voteEndTime) {
                return(false, 8);
            }
        }
        return(true, 0);
    }
    
    uint8 public errorCode = 0;
    uint256 public errorMessage = 0;
    function invest(uint8 stageId) public payable returns(uint8, uint256) {
        /**
         * 100 - 初始状态
         * 101 - 不在Token销售时间内
         * 102 - 金额不在规定范围内
         * 103 - 已经达到硬顶，将收到金额打回
         * 104 - 投资人补投成功
         * 105 - 投资人新投成功
         * 106 - 已经停止
         * 
         * 第二个返回参数是实际投资额
         */
        require(stageId >= 0 && stageId <= stages.length);
        require(stages.length < 30 && stages.length > 0);
        
        require(msg.value > 0); //判断ETH金额是否大于0
        //首先判断时间，处于哪个阶段，是否接受打币
        //Stage memory p = stages[stageId];
        if(!(now <= stages[stageId].time.saleEndTime && now >= stages[stageId].time.saleStartTime)) {
            msg.sender.transfer(msg.value);
            errorCode = 101;
            errorMessage = now;
            return(101, 0);
        } else if(!stages[stageId].actived) {
            msg.sender.transfer(msg.value);
            errorCode = 106;
            return(106, 0);
        } else if(stages[stageId].raisedAmount >= stages[stageId].totalAmount) {
            msg.sender.transfer(msg.value);
            errorCode = 103;
            return(103, 0);
        } else {
            //开始处理投资
            if(msg.value >= stages[stageId].minWei && msg.value <= stages[stageId].maxWei) {
                if(stages[stageId].raisedAmount < stages[stageId].totalAmount) {
                    uint256 valueNeed = msg.value;
                    stages[stageId].raisedAmount = stages[stageId].raisedAmount.add(msg.value);
                    stages[stageId].balanceAmount = stages[stageId].balanceAmount.add(msg.value);
                    if(stages[stageId].raisedAmount > stages[stageId].totalAmount) {
                        //Return back the balance amount of more than totalAmount 
                        uint256 valueLeft = stages[stageId].raisedAmount.sub(stages[stageId].totalAmount);
                        valueNeed = msg.value.sub(valueLeft);
                        msg.sender.transfer(valueLeft);
                        stages[stageId].raisedAmount = stages[stageId].balanceAmount = stages[stageId].totalAmount;
                    }

                    //Tokens
                    uint256 tokenValue = valueNeed.mul(stages[stageId].changeRate);
                    
                    //transfer from owner's account to investor's account
                    balances[owner] = balances[owner].sub(tokenValue);
                    
                    (bool foundInvestor, uint256 id) = getInvestorId(msg.sender, stageId);

                    if(foundInvestor) {
                        investors[id].ethAmount = investors[id].ethAmount.add(valueNeed);
                        investors[id].tokens = investors[id].tokens.add(tokenValue);
                        errorCode = 104;
                        errorMessage = valueNeed;
                        return(104, valueNeed);
                    } else {
                        Investor memory inv;
                        inv.investor = msg.sender;
                        inv.stageId = stageId;
                        inv.ethAmount = valueNeed;
                        inv.tokens = tokenValue;
                        inv.voteStatus = 0;
                        investors.push(inv);
                        errorCode = 105;
                        errorMessage = valueNeed;
                        return(105, valueNeed);
                    }
                    //emit Transfer(owner, msg.sender, tokenValue);
                }
            } else {
                //金额不在规定范围内
                msg.sender.transfer(msg.value);
                errorCode = 102;
                return(102, 0);
            }  
        }
    }

    function withdrawTokenForStage(uint8 stageId) public payable returns(uint8, uint256) {
        //从某一阶段中提现已经解冻的代币
        /**
         * 返回值
         * 100 - 成功
         * 101 - 用户不存在
         * 102 - 用户存在，但是可提代币为0
         * 103 - 该轮投票还没结束
         * 104 - 用户在操作本步骤时打了eth
         */
        require(stageId >= 0 && stageId <= stages.length);
        require(stages.length < 30 && stages.length > 0);
        
        if(msg.value > 0) {
            //如果用户不慎打了eth，则原路返回
            msg.sender.transfer(msg.value);
            errorCode = 104;
            return(104, msg.value);
        }
        
        //检验该阶段投票是否结束，投票结果是否通过
        if(stages[stageId].isPass) {
            //检测该用户是否存在于该阶段中
            (bool has, uint256 id) = getInvestorId(msg.sender, stageId);

            if(has) {
                uint256 freeToken = investors[id].tokens;
                if(freeToken > 0) {
                    balances[msg.sender] = balances[msg.sender].add(freeToken); //提取代币
                    investors[id].tokens = 0;
                    errorCode = 100;
                    return(100, freeToken);
                } else {
                    errorCode = 102;
                    return(102, 0);
                }
            } else {
                errorCode = 101;
                return(101, 0);
            }
        } else {
            errorCode = 103;
            return(103, 0);
        }
    }
    
    function withdrawAllToken() public payable returns(uint8, uint256) {
        //从所有未提的已经解冻的Token提取
        /**
         * 返回值
         * 100 - 成功
         * 101 - 提现金额为0
         * 104 - 用户在操作本步骤时打了eth
         */
        if(msg.value > 0) {
            //如果用户不慎打了eth，则原路返回
            msg.sender.transfer(msg.value);
            errorCode = 104;
            return(104, msg.value);
        }
        
        //检验该阶段投票是否结束，投票结果是否通过
        uint256 totalWithdrawTokens = 0;
        for(uint8 stageId = 0; stageId < stages.length; stageId++) {
            if(stages[stageId].isPass) {
                //检测该用户是否存在于该阶段中
                (bool has, uint256 id) = getInvestorId(msg.sender, stageId);

                if(has) {
                    uint256 freeToken = investors[id].tokens;
                    if(freeToken > 0) {
                        totalWithdrawTokens = totalWithdrawTokens.add(freeToken);
                        investors[id].tokens = 0;
                    }
                }
            }            
        }
        if(totalWithdrawTokens > 0) {
            balances[msg.sender] = balances[msg.sender].add(totalWithdrawTokens);
            errorCode = 100;
            return(100, totalWithdrawTokens);
        } else {
            errorCode = 101;
            return(101, 0);
        }
    }
    
    function getStageData(uint8 stageId, uint8 dataId) public view returns(uint256) {
        //返回某一阶段的数据，测试用
        //dataId:
        //1 - totalAmount;                    //Total amount of ethereum (Wei) for this stage
        //2 - raisedAmount;                   //Raised amount of ethereum (Wei) for this stage
        //3 - balanceAmount;                  //Balance amount of ethereum (Wei) for this stage
        //4 - changeRate;                     //How many tokens for 1 eth
        //5 - minWei;                         //Minimum ethereum (Wei) to invest for this stage
        //6 - maxWei;                         //Maximum ethereum (Wei) to invest for this stage
        //7 - refundDiscount;                 //If vote result is stop ico, deduce this percent than return back to investors
        //8 - actived;                          //Current stage is actived
        //9 - isPass;                           //If the vote for agree more than oppose, set to true.
        //10 - time.saleStartTime;
        //11 - time.saleEndTime;
        //12 - time.lockStartTime;
        //13 - time.lockEndTime;
        //14 - time.voteStartTime;
        //15 - time.voteEndTime;
        //16 - vote.targetVoteRate;
        //17 - vote.targetAgreeRate;
        //18 - vote.currentVoteRate;
        //19 - vote.currentAgreeRate;
        //20 - vote.currentInvestors;
        //21 - vote.currentAgreeVotes;
        //22 - vote.currentOpposeVotes;

        require(stageId >= 0 && stageId <= stages.length);
        require(stages.length < 30 && stages.length > 0);
        
        if(dataId == 1) return stages[stageId].totalAmount;
        else if(dataId == 2) return stages[stageId].raisedAmount;
        else if(dataId == 3) return stages[stageId].balanceAmount;
        else if(dataId == 4) return stages[stageId].changeRate;
        else if(dataId == 5) return stages[stageId].minWei;
        else if(dataId == 6) return stages[stageId].maxWei;
        else if(dataId == 7) return stages[stageId].refundDiscount;
        else if(dataId == 8) return stages[stageId].actived ? 1 : 0;
        else if(dataId == 9) return stages[stageId].isPass ? 1 : 0;
        
        else if(dataId == 10) return stages[stageId].time.saleStartTime;
        else if(dataId == 11) return stages[stageId].time.saleEndTime;
        else if(dataId == 12) return stages[stageId].time.lockStartTime;
        else if(dataId == 13) return stages[stageId].time.lockEndTime;
        else if(dataId == 14) return stages[stageId].time.voteStartTime;
        else if(dataId == 15) return stages[stageId].time.voteEndTime;
        
        else if(dataId == 16) return stages[stageId].vote.targetVoteRate;
        else if(dataId == 17) return stages[stageId].vote.targetAgreeRate;
        else if(dataId == 18) return stages[stageId].vote.currentVoteRate;
        else if(dataId == 19) return stages[stageId].vote.currentAgreeRate;
        else if(dataId == 20) return stages[stageId].vote.currentInvestors;
        else if(dataId == 21) return stages[stageId].vote.currentAgreeVotes;
        else if(dataId == 22) return stages[stageId].vote.currentOpposeVotes;
        else return(0);
    }
    
    function withdrawEthForStage(uint8 stageId, uint256 weiAmount) public payable returns(uint8, uint256) {
        //合约主人提取已经解冻的以太坊
        /**
         * 返回值
         * 100 - 成功
         * 101 - 用户不存在
         * 102 - 余额不够
         * 103 - 该轮投票还没通过
         * 104 - 用户在操作本步骤时打了eth
         * 105 - 不是owner
         */
        require(stageId >= 0 && stageId <= stages.length);
        require(stages.length < 30 && stages.length > 0);
        require(weiAmount > 0);

        if(msg.sender != owner) {
            errorCode = 105;
            return(105, 0);
        }

        if(msg.value > 0) {
            //如果合约所有人不慎打了eth，则原路返回
            owner.transfer(msg.value);
            errorCode = 104;
            return(104, msg.value);
        }

        //检验该阶段投票是否结束，投票结果是否通过
        if(stages[stageId].isPass) {
            if(weiAmount > stages[stageId].balanceAmount) {
                errorCode = 102;
                return(102, weiAmount);
            } else {
                msg.sender.transfer(weiAmount);
                stages[stageId].balanceAmount = stages[stageId].balanceAmount.sub(weiAmount);
                errorCode = 100;
                return(100, weiAmount);
            }
        } else {
            errorCode = 103;
            return(103, 0);
        }
    }
    
    function withdrawEthForNonPassStage(uint8 stageId, uint256 weiAmount, bool all) public payable returns(uint8, uint256) {
        //The investors withdraw eth by themselves if the stage is fail to continue
        //Returns:
        //101 - Vote has not ended.
        //102 - Vote has passed, can not withdraw eth.
        //103 - The sender has not invested for the current stage.
        //104 - The applied amount is not enough.
        require(weiAmount > 0);
        if(now > stages[stageId].time.voteEndTime) {
            if(!stages[stageId].isPass) {
                (bool has, uint256 id) = getInvestorId(msg.sender, stageId);
                if(has) {
                    if(all) {
                        weiAmount = investors[id].ethAmount;
                    }
                    if(investors[id].ethAmount >= weiAmount) {
                        investors[id].ethAmount = investors[id].ethAmount.sub(weiAmount);
                        investors[id].tokens = investors[id].tokens.sub(weiAmount.mul(stages[stageId].changeRate));
                        uint256 refundAmount = weiAmount.mul(100 - stages[stageId].refundDiscount).div(100);
                        //Refund to investor
                        msg.sender.transfer(refundAmount);
                        //Send refund fee to owner
                        require(weiAmount - refundAmount > 0);
                        owner.transfer(weiAmount - refundAmount);
                    } else {
                        errorCode = 104;
                        return(104, 0);
                    }
                } else {
                    errorCode = 103;
                    return(103, 0);
                }
            } else {
                errorCode = 102;
                return(102, 0);
            }
        } else {
            errorCode = 101;
            return(101, 0);
        }
    }
    
    function stopICO() public onlyOwner payable {
        //终止ICO，全部退回ETH
        uint256 totalEthAmount = 0;
        for(uint8 i = 0; i < stages.length; i++) {
            stages[i].actived = false;
            stages[i].isPass = false;
            totalEthAmount = totalEthAmount.add(stages[i].balanceAmount);
            stages[i].balanceAmount = 0;
        }
    }
    
    function vote(uint8 stageId, uint8 isAggree) public payable returns(uint8, uint8) {
        //投票
        //isAggree = 1 赞成票, 2- 反对票
        //100 - 成功投票
        //101 - 参数不正确，1为同意，2为否决
        //102 - 不在投票时间段，或者该阶段已经被取消
        //103 - 该投票用户没有参与投资
        //104 - 已经投过票，不能重复投票
        //105 - 投赞成票
        //106 - 投反对票，已将代币清除，并将以太坊返还
        
        if(now <= stages[stageId].time.voteEndTime && now >= stages[stageId].time.voteStartTime) {
            //The current stage is voting.
            (bool hasInvested, uint256 id) = getInvestorId(msg.sender, stageId);
    
            if(hasInvested) {
                if(investors[id].voteStatus == 0) {
                    if(isAggree == 1 || isAggree == 2) {
                        investors[id].voteStatus = isAggree;
                        
                        //Change the vote tatus
                        changeVoteStatus(stageId);
    
                        //Check the result of current stage after this vote
                        checkVoteResult(stageId);
                        
                        //Simple code for:
                        /*
                        if(isAggree == 2) {
                            return(106, stageId);
                        } else {
                            return(105, stageId);
                        }
                        */
                        errorCode = 104 + isAggree;
                        return(104 + isAggree, stageId);

                    } else {
                        errorCode = 101;
                        return(101, stageId);
                    }
                } else {
                    errorCode = 104;
                    return(104, stageId);
                }
            } else {
                errorCode = 103;
                return (103, stageId);
            }        
        } else {
            //Out of voting
            errorCode = 102;
            return(102, stageId);
        }
    
    }
    
    function checkVoteResult(uint8 stageId) private {
        //检查投票是否结束
        Stage memory s = stages[stageId];
        if(s.vote.currentVoteRate >= s.vote.targetVoteRate.mul(100) && s.vote.currentAgreeRate >= s.vote.targetAgreeRate.mul(100)) {
            stages[stageId].isPass = true;
        }
    }
    
    function changeVoteStatus(uint8 stageId) private {
        //查看当前投票情况
        //统计投票人次以及投票结果
        uint256 totalInvestors = 0;
        uint256 agreeVotes = 0;
        uint256 opposeVotes = 0;
        for(uint256 j = 0; j < investors.length; j++) {
            Investor memory inv = investors[j];
            if(inv.stageId == stageId) {
                if(stages[stageId].vote.amountWeighting) {
                    //Count by investors' amount
                    totalInvestors = totalInvestors.add(inv.ethAmount);
                    if(inv.voteStatus == 1) agreeVotes = agreeVotes.add(inv.ethAmount);
                    else if(inv.voteStatus == 2) opposeVotes = opposeVotes.add(inv.ethAmount);
                } else {
                    //Count by investors
                    totalInvestors++;
                    if(inv.voteStatus == 1) agreeVotes++;
                    else if(inv.voteStatus == 2) opposeVotes++;
                }
            }
        }
        
        //计算投票率和票数结果
        uint256 voteRate = (agreeVotes.add(opposeVotes)).mul(10000).div(totalInvestors); //是四位数，以精确到小数点后2位
        uint256 agreeRate = agreeVotes.mul(10000).div(totalInvestors);//赞同票数的比例
        
        stages[stageId].vote.currentInvestors = totalInvestors;
        stages[stageId].vote.currentAgreeVotes = agreeVotes;
        stages[stageId].vote.currentOpposeVotes = opposeVotes;
        stages[stageId].vote.currentVoteRate = uint256(voteRate);
        stages[stageId].vote.currentAgreeRate = uint256(agreeRate);
    }
    
    function getInvestorId(address user, uint8 stageId) public view returns(bool, uint256) {
        bool hasInvested = false;
        uint256 id = 0;
        for(uint256 j = 0; j < investors.length; j++) {
            if(investors[j].investor == user && investors[j].stageId == stageId) {
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
    // Change owner
    // ------------------------------------------------------------------------
    function changeOwner(address newOwner) public onlyOwner returns(bool) {
        require(newOwner != address(0));
        uint256 balanceOfOwner = balances[owner];
        balances[owner] = 0;
        owner = newOwner;
        balances[owner] = balances[owner].add(balanceOfOwner);
        return true;
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
