pragma solidity ^0.5.11;

import "./EIP20Interface.sol";
import "./CTokenInterface.sol";
import "./SafeMath.sol";
import "./GrowdropManager.sol";
import "./UniswapFactoryInterface.sol";
import "./UniswapExchangeInterface.sol";

contract Growdrop {
    using SafeMath for uint256;

    GrowdropManager public manager;
    
    EIP20Interface public Token;
    
    EIP20Interface public GrowdropToken;
    
    CTokenInterface public CToken;
    
    UniswapFactoryInterface public UniswapFactory;
    UniswapExchangeInterface public UniswapDaiExchange;
    
    address public Beneficiary;
    
    //ctoken balanceOf per address
    mapping(address => uint256) public CTokenPerAddress;
    
    //minted token balance per address
    mapping(address => uint256) public InvestAmountPerAddress;
    
    //checks address withdraw
    mapping(address => bool) public WithdrawOver;
    
    //token amount to give investors
    uint256 public GrowdropAmount;
    
    //start time of Growdrop
    uint256 public GrowdropStartTime;
    
    //end time of mint and redeem
    uint256 public GrowdropEndTime;
    
    //total minted token balance
    uint256 public TotalMintedAmount;
    uint256 public TotalCTokenAmount;
    
    uint256 constant ConstVal=10**18;
    
    //exchangeRateStored value when Growdrop ends
    uint256 public ExchangeRateOver;
    
    //total interests Growdrop contracts get when Growdrop ends
    uint256 public TotalInterestOver;
    
    uint256 public ToUniswapTokenAmount;
    uint256 public ToUniswapInterestRate;
    
    //whether Growdrop is over
    bool public GrowdropOver;

    //whether Growdrop is started
    bool public GrowdropStart;
    
    //makes Growdrop contract (not start)
    constructor(
        address TokenAddr, 
        address CTokenAddr, 
        address GrowdropTokenAddr, 
        address BeneficiaryAddr, 
        uint256 _GrowdropAmount, 
        uint256 GrowdropApproximateStartTime, 
        uint256 GrowdropPeriod, 
        uint256 _ToUniswapTokenAmount, 
        uint256 _ToUniswapInterestRate,
        address UniswapFactoryAddr,
        address UniswapDaiExchangeAddr) public {
        Token = EIP20Interface(TokenAddr);
        CToken = CTokenInterface(CTokenAddr);
        GrowdropToken = EIP20Interface(GrowdropTokenAddr);
        Beneficiary = BeneficiaryAddr;
        GrowdropAmount=_GrowdropAmount;
        GrowdropStartTime=GrowdropApproximateStartTime;
        GrowdropEndTime=GrowdropStartTime.add(GrowdropPeriod);
        manager=GrowdropManager(msg.sender);
        UniswapFactory = UniswapFactoryInterface(UniswapFactoryAddr);
        UniswapDaiExchange=UniswapExchangeInterface(UniswapDaiExchangeAddr);
        require(_ToUniswapInterestRate>0 && _ToUniswapInterestRate<98);
        ToUniswapTokenAmount=_ToUniswapTokenAmount;
        ToUniswapInterestRate=_ToUniswapInterestRate;
    }
    
    //start Growdrop
    function StartGrowdrop() public returns (bool) {
        require(msg.sender==Beneficiary);
        require(!GrowdropStart);
        GrowdropStart=true;
        
        //need to approve from msg.sender to this contract first
        require(GrowdropToken.transferFrom(msg.sender, address(this), GrowdropAmount.add(ToUniswapTokenAmount)));
        
        uint256 period = GrowdropEndTime.sub(GrowdropStartTime);

        //Growdrop start time is now
        GrowdropStartTime=now;
        
        //Growdrop ends now+GrowdropTime
        GrowdropEndTime=now.add(period);
        
        //event
        require(manager.emitGrowdropActionEvent(false, GrowdropStartTime));
        return true;
    }
    
    //investor mint token and Growdrop contract gets interests (not only once, can mint over time)
    function Mint(uint256 Amount) public returns (bool) {
        require(GrowdropStart);
        require(now<GrowdropEndTime);
        require(msg.sender!=Beneficiary);
        
        //need to approve from msg.sender to this contract first
        require(Token.transferFrom(msg.sender, address(this), Amount));
        
        //investor's minted token balance increases 
        InvestAmountPerAddress[msg.sender]=InvestAmountPerAddress[msg.sender].add(Amount);
        
        //total minted token balance increases
        TotalMintedAmount=TotalMintedAmount.add(Amount);
        
        //Growdrop contract's balanceOf ctoken before mint
        uint256 beforeBalance = CToken.balanceOf(address(this));
        
        //first approve to mint
        require(Token.approve(address(CToken), Amount));
        
        //mint ctoken ( ex) compound mint )  
        require(CToken.mint(Amount)==0);
        
        
        uint256 BalanceDif = CToken.balanceOf(address(this)).sub(beforeBalance);
        
        //investor's balanceOf ctoken increases
        CTokenPerAddress[msg.sender]=CTokenPerAddress[msg.sender].add(BalanceDif);
        TotalCTokenAmount=TotalCTokenAmount.add(BalanceDif);
        
        //event
        if(!manager.CheckUserJoinedGrowdrop(address(this),msg.sender)) {
            require(manager.emitUserActionEvent(msg.sender, 0, now, 4, 0));
        }
        require(manager.emitUserActionEvent(msg.sender, InvestAmountPerAddress[msg.sender], now, 0, Amount));
        return true;
    }
    
    //investor redeem token and Growdrop contract gives token to investor, investor cannot get interests (not only once, can redeem over time)
    function Redeem(uint256 Amount) public returns (bool) {
        require(GrowdropStart);
        require(now<GrowdropEndTime);
        require(msg.sender!=Beneficiary);
        
        require(InvestAmountPerAddress[msg.sender]>=Amount);
        
        //investor's minted token balance decreases
        InvestAmountPerAddress[msg.sender]=InvestAmountPerAddress[msg.sender].sub(Amount);
        
        //total minted token balance decreases
        TotalMintedAmount=TotalMintedAmount.sub(Amount);
        
        //Growdrop contract's balanceOf ctoken before redeem
        uint256 beforeBalance = CToken.balanceOf(address(this));
        
        //redeem ctoken ( ex) compound redeemUnderlying )
        require(CToken.redeemUnderlying(Amount)==0);
        
        //transfer redeemed token balance to investor
        require(Token.transfer(msg.sender, Amount));
        
        uint256 BalanceDif = beforeBalance.sub(CToken.balanceOf(address(this)));
        //investor's balanceOf ctoken decreases
        CTokenPerAddress[msg.sender]=CTokenPerAddress[msg.sender].sub(BalanceDif);
        TotalCTokenAmount=TotalCTokenAmount.sub(BalanceDif);
        
        //event
        require(manager.emitUserActionEvent(msg.sender, InvestAmountPerAddress[msg.sender], now, 1, Amount));
        return true;
    }
    
    function Withdraw(bool ToUniswap) public returns (bool) {
        require(!WithdrawOver[msg.sender]);
        
        //change state
        WithdrawOver[msg.sender]=true;
        
        EndGrowdrop();
        
        if(msg.sender==Beneficiary) {
            uint256 OwnerFee=TotalInterestOver.mul(3).div(100);
            if(ToUniswap) {
                uint256 ToUniswapInterestRateCalculated = TotalInterestOver.mul(ToUniswapInterestRate).div(100);
                require(Token.transfer(Beneficiary, TotalInterestOver.sub(ToUniswapInterestRateCalculated).sub(OwnerFee)));
            
                if(!AddToUniswap(ToUniswapInterestRateCalculated)) {
                    sendTokenInWithdraw(Beneficiary, ToUniswapInterestRateCalculated, ToUniswapTokenAmount);
                }
                require(manager.emitUniswapAddedEvent(address(GrowdropToken), ToUniswapInterestRateCalculated, ToUniswapTokenAmount, now));
            } else {
                sendTokenInWithdraw(Beneficiary, TotalInterestOver.sub(OwnerFee), ToUniswapTokenAmount);
            }
            require(Token.transfer(manager.Owner(), OwnerFee));
            
            //event
            require(manager.emitUserActionEvent(msg.sender, 0, now, 2, 0));
        } else {
            sendTokenInWithdraw(msg.sender, InvestAmountPerAddress[msg.sender], TokenByInterest(msg.sender));
            //event
            require(manager.emitUserActionEvent(msg.sender, TokenByInterest(msg.sender), now, 3, InvestAmountPerAddress[msg.sender]));
        }
        return true;
    }
    
    function sendTokenInWithdraw(address To, uint256 TokenAmount, uint256 GrowdropTokenAmount) private {
        require(Token.transfer(To, TokenAmount));
        require(GrowdropToken.transfer(To, GrowdropTokenAmount));
    }
    
    function EndGrowdrop() public {
        require(GrowdropStart && GrowdropEndTime<=now);
        if(!GrowdropOver) {
            
            //change state
            GrowdropOver=true;
            address owner=manager.Owner();
            
            require(CToken.transfer(owner, CToken.balanceOf(address(this)).sub(TotalCTokenAmount)));
            
            //store last exchangeRateStored to calculate
            ExchangeRateOver = CToken.exchangeRateCurrent();
            //redeem all ctoken balance of Growdrop contract, and there will be no more interests from Growdrop contract
            require(CToken.redeem(TotalCTokenAmount)==0);
            
            uint256 calculatedBalance = MulAndDiv(TotalCTokenAmount, ExchangeRateOver, ConstVal);
            
            require(Token.transfer(owner, Token.balanceOf(address(this)).sub(calculatedBalance)));
            //store last interests to calculate
            TotalInterestOver = calculatedBalance.sub(TotalMintedAmount);
            
            //event
            require(manager.emitGrowdropActionEvent(true, now));
        }
    }
    
    function AddToUniswap(uint256 daiAmount) private returns (bool) {
        address newTokenExchangeAddr = UniswapFactory.getExchange(address(GrowdropToken)); 
        if(newTokenExchangeAddr==address(0x0)) {
            newTokenExchangeAddr = UniswapFactory.createExchange(address(GrowdropToken));
        }
        UniswapExchangeInterface newTokenExchange = UniswapExchangeInterface(newTokenExchangeAddr);
        
        uint256 daiToEthAmount = UniswapDaiExchange.getTokenToEthInputPrice(daiAmount);
        if(daiToEthAmount<1000000000) {
            return false;
        }
        
        uint256 max_token=0;
        uint256 min_liquidity=0;
        if (newTokenExchange.totalSupply()==0) {
            changeDaiToEth(daiAmount, daiToEthAmount);
            min_liquidity = address(newTokenExchange).balance.add(daiToEthAmount);
            addLiquidityAndTransfer(daiToEthAmount,min_liquidity,ToUniswapTokenAmount,newTokenExchange);
        } else {
            uint256 eth_reserve = address(newTokenExchange).balance;
            uint256 token_reserve = GrowdropToken.balanceOf(address(newTokenExchange));
            uint256 total_liquidity = newTokenExchange.totalSupply();
            max_token = MulAndDiv(daiToEthAmount, token_reserve, eth_reserve).add(1);
            min_liquidity = MulAndDiv(daiToEthAmount, total_liquidity, eth_reserve);
            if(max_token>ToUniswapTokenAmount) {
                return addLiquidityAndTransferLower(eth_reserve,token_reserve,total_liquidity,ToUniswapTokenAmount,daiAmount,newTokenExchange);
            } else {
                changeDaiToEth(daiAmount, daiToEthAmount);
                addLiquidityAndTransfer(daiToEthAmount,min_liquidity,max_token,newTokenExchange);
                require(GrowdropToken.transfer(Beneficiary, ToUniswapTokenAmount-max_token));
            }
        }
        return true;
    }
    
    function addLiquidityAndTransferLower(uint256 eth_reserve, uint256 token_reserve, uint256 total_liquidity, uint256 newTokenAmount, uint256 daiAmount, UniswapExchangeInterface tokenExchange) private returns (bool) {
        uint256 lowerEthAmount = MulAndDiv(newTokenAmount.sub(1), eth_reserve, token_reserve);
        if(lowerEthAmount<1000000000) {
            return false;
        }
        uint256 max_token = MulAndDiv(lowerEthAmount, token_reserve, eth_reserve).add(1);
        uint256 min_liquidity = MulAndDiv(lowerEthAmount, total_liquidity, eth_reserve);
                
        uint256 lowerDaiAmount = UniswapDaiExchange.getTokenToEthOutputPrice(lowerEthAmount);
        changeDaiToEth(lowerDaiAmount, lowerEthAmount);
        addLiquidityAndTransfer(lowerEthAmount, min_liquidity, max_token, tokenExchange);
        sendTokenInWithdraw(Beneficiary, daiAmount.sub(lowerDaiAmount), newTokenAmount.sub(max_token));
        return true;
    }
    
    function addLiquidityAndTransfer(uint256 ethAmount, uint256 liquidity, uint256 tokenAmount, UniswapExchangeInterface tokenExchange) private {
        require(GrowdropToken.approve(address(tokenExchange),tokenAmount));
        require(liquidity==tokenExchange.addLiquidity.value(ethAmount)(liquidity,tokenAmount,1739591241));
        require(tokenExchange.transfer(Beneficiary, liquidity));
    }
    
    function changeDaiToEth(uint256 daiAmount, uint256 daiToEthAmount) private {
        require(Token.approve(address(UniswapDaiExchange), daiAmount));
        require(daiToEthAmount==UniswapDaiExchange.tokenToEthTransferInput(daiAmount, daiToEthAmount, 1739591241, address(this)));
    }
    
    function TotalBalance() public view returns (uint256) {
        if(GrowdropOver) {
            return TotalInterestOver.add(TotalMintedAmount);
        }
        return MulAndDiv(TotalCTokenAmount, CToken.exchangeRateStored(), ConstVal);
    }
    
    function TotalPerAddress(address Investor) public view returns (uint256) {
        if(GrowdropOver) {
            return MulAndDiv(CTokenPerAddress[Investor], ExchangeRateOver, ConstVal);
        }
        return MulAndDiv(CTokenPerAddress[Investor], CToken.exchangeRateStored(), ConstVal);
    }
    
    function InterestRate(address Investor) public view returns (uint256) {
        if(GrowdropOver) {
            return MulAndDiv(TotalPerAddress(Investor).sub(InvestAmountPerAddress[Investor]), ConstVal, TotalInterestOver);
        }
        return MulAndDiv(TotalPerAddress(Investor).sub(InvestAmountPerAddress[Investor]), ConstVal, TotalBalance().sub(TotalMintedAmount));
    }
    
    function TokenByInterest(address Investor) public view returns (uint256) {
        return MulAndDiv(InterestRate(Investor), GrowdropAmount, ConstVal);
    }
    
    function MulAndDiv(uint256 a, uint256 b, uint256 c) private pure returns (uint256) {
        return a.mul(b).div(c);
    }
    
    function getGrowdropData() public view returns (address, address, uint256, uint256, uint256, uint256, uint256, bool, bool, uint256, uint256) {
        return (address(GrowdropToken), Beneficiary, GrowdropAmount, GrowdropStartTime, GrowdropEndTime, TotalBalance(), TotalMintedAmount, GrowdropOver, GrowdropStart, ToUniswapTokenAmount, ToUniswapInterestRate);
    }
    
    function getUserData() public view returns (uint256, uint256, uint256, uint256, uint256) {
        return (InvestAmountPerAddress[msg.sender], TotalPerAddress(msg.sender), TotalPerAddress(msg.sender).sub(InvestAmountPerAddress[msg.sender]), InterestRate(msg.sender), TokenByInterest(msg.sender));
    }
    
    function () external payable {
        
    }
}
