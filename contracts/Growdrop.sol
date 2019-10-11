pragma solidity ^0.5.11;

import "./EIP20Interface.sol";
import "./CTokenInterface.sol";
import "./GrowdropManagerInterface.sol";
import "./UniswapFactoryInterface.sol";
import "./UniswapExchangeInterface.sol";
import "./UniswapDaiSwapInterface.sol";
import "./KyberNetworkProxyInterface.sol";

contract Growdrop {

    GrowdropManagerInterface public manager;
    
    EIP20Interface public Token;
    
    EIP20Interface public GrowdropToken;
    
    CTokenInterface public CToken;
    
    UniswapFactoryInterface public UniswapFactory;
    UniswapExchangeInterface public UniswapNewTokenExchange;
    
    KyberNetworkProxyInterface public KyberNetworkProxy;
    EIP20Interface public EthToken;
    EIP20Interface public KyberToken;
    
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
    //should be 10**15, only for kovan
    uint256 constant KyberMinimum=10**9;
    
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
        uint256 GrowdropPeriod, 
        uint256 _ToUniswapTokenAmount, 
        uint256 _ToUniswapInterestRate,
        address KyberTokenAddr) public {
        Token = EIP20Interface(TokenAddr);
        CToken = CTokenInterface(CTokenAddr);
        GrowdropToken = EIP20Interface(GrowdropTokenAddr);
        Beneficiary = BeneficiaryAddr;
        GrowdropAmount=_GrowdropAmount;
        
        require(GrowdropPeriod>0);
        GrowdropEndTime=GrowdropPeriod;
        
        manager=GrowdropManagerInterface(msg.sender);
        
        require(_ToUniswapInterestRate>0 && _ToUniswapInterestRate<98);
        require(_ToUniswapTokenAmount>1000000000 && _GrowdropAmount>1000000000);
        require(_GrowdropAmount+_ToUniswapTokenAmount>=_ToUniswapTokenAmount);
        ToUniswapTokenAmount=_ToUniswapTokenAmount;
        ToUniswapInterestRate=_ToUniswapInterestRate;
        
        //kovan address
        UniswapFactory = UniswapFactoryInterface(0xD3E51Ef092B2845f10401a0159B2B96e8B6c3D30);
        KyberNetworkProxy = KyberNetworkProxyInterface(0x692f391bCc85cefCe8C237C01e1f636BbD70EA4D);
        EthToken = EIP20Interface(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        //KyberToken = EIP20Interface(0xC4375B7De8af5a38a93548eb8453a498222C4fF2);
        //only for kovan
        KyberToken = EIP20Interface(KyberTokenAddr);
    }
    
    //start Growdrop
    function StartGrowdrop() public {
        require(msg.sender==Beneficiary);
        require(!GrowdropStart);
        GrowdropStart=true;
        
        //need to approve from msg.sender to this contract first
        require(GrowdropToken.transferFrom(msg.sender, address(this), GrowdropAmount+ToUniswapTokenAmount));

        //Growdrop start time is now
        GrowdropStartTime=now;
        
        //Growdrop ends now+GrowdropTime
        require(now+GrowdropEndTime>GrowdropEndTime);
        GrowdropEndTime+=now;
        
        //event
        require(manager.emitGrowdropActionEvent(false, GrowdropStartTime));
    }
    
    //investor mint token and Growdrop contract gets interests (not only once, can mint over time)
    function Mint(uint256 Amount) public {
        require(GrowdropStart);
        require(now<GrowdropEndTime);
        require(msg.sender!=Beneficiary);
        require(Amount>0);
        
        //need to approve from msg.sender to this contract first
        require(Token.transferFrom(msg.sender, address(this), Amount));
        
        //investor's minted token balance increases 
        InvestAmountPerAddress[msg.sender]+=Amount;
        require(InvestAmountPerAddress[msg.sender]>=Amount);
        
        //total minted token balance increases
        TotalMintedAmount+=Amount;
        require(TotalMintedAmount>=Amount);
        
        //Growdrop contract's balanceOf ctoken before mint
        uint256 beforeBalance = CToken.balanceOf(address(this));
        
        //first approve to mint
        require(Token.approve(address(CToken), Amount));
        
        //mint ctoken ( ex) compound mint )  
        require(CToken.mint(Amount)==0);
        
        
        uint256 BalanceDif = CToken.balanceOf(address(this))-beforeBalance;
        
        require(BalanceDif>0 && TotalCTokenAmount+BalanceDif>=BalanceDif);
        //investor's balanceOf ctoken increases
        CTokenPerAddress[msg.sender]+=BalanceDif;
        TotalCTokenAmount+=BalanceDif;
        
        //event
        if(!manager.CheckUserJoinedGrowdrop(address(this),msg.sender)) {
            require(manager.emitUserActionEvent(msg.sender, 0, now, 4, 0));
        }
        require(manager.emitUserActionEvent(msg.sender, InvestAmountPerAddress[msg.sender], now, 0, Amount));
    }
    
    //investor redeem token and Growdrop contract gives token to investor, investor cannot get interests (not only once, can redeem over time)
    function Redeem(uint256 Amount) public {
        require(GrowdropStart);
        require(now<GrowdropEndTime);
        require(msg.sender!=Beneficiary);
        require(Amount>0);
        
        require(InvestAmountPerAddress[msg.sender]>=Amount);
        
        //investor's minted token balance decreases
        InvestAmountPerAddress[msg.sender]-=Amount;
        
        //total minted token balance decreases
        TotalMintedAmount-=Amount;
        
        //Growdrop contract's balanceOf ctoken before redeem
        uint256 beforeBalance = CToken.balanceOf(address(this));
        
        //redeem ctoken ( ex) compound redeemUnderlying )
        require(CToken.redeemUnderlying(Amount)==0);
        
        //transfer redeemed token balance to investor
        require(Token.transfer(msg.sender, Amount));
        
        require(beforeBalance>CToken.balanceOf(address(this)));
        uint256 BalanceDif = beforeBalance-CToken.balanceOf(address(this));
        //investor's balanceOf ctoken decreases
        CTokenPerAddress[msg.sender]-=BalanceDif;
        TotalCTokenAmount-=BalanceDif;
        
        //event
        require(manager.emitUserActionEvent(msg.sender, InvestAmountPerAddress[msg.sender], now, 1, Amount));
    }
    
    function Withdraw(bool ToUniswap) public {
        require(!WithdrawOver[msg.sender]);
        
        //change state
        WithdrawOver[msg.sender]=true;
        
        EndGrowdrop();
        
        if(msg.sender==Beneficiary) {
            uint256 OwnerFee=MulAndDiv(TotalInterestOver, 3, 100);
            if(ToUniswap) {
                uint256 ToUniswapInterestRateCalculated = MulAndDiv(TotalInterestOver, ToUniswapInterestRate, 100);
                require(Token.transfer(Beneficiary, TotalInterestOver-ToUniswapInterestRateCalculated-OwnerFee));
            
                AddToUniswap(ToUniswapInterestRateCalculated);
            } else {
                sendTokenInWithdraw(Token, Beneficiary, TotalInterestOver-OwnerFee, ToUniswapTokenAmount);
            }
            require(Token.transfer(manager.Owner(), OwnerFee));
            
            //event
            require(manager.emitUserActionEvent(msg.sender, 0, now, 2, 0));
        } else {
            uint256 tokenByInterest = MulAndDiv(InterestRate(msg.sender), GrowdropAmount, ConstVal);
            sendTokenInWithdraw(Token, msg.sender, InvestAmountPerAddress[msg.sender], tokenByInterest);
            //event
            require(manager.emitUserActionEvent(msg.sender, tokenByInterest, now, 3, InvestAmountPerAddress[msg.sender]));
        }
    }
    
    function sendTokenInWithdraw(EIP20Interface token, address To, uint256 TokenAmount, uint256 GrowdropTokenAmount) private {
        require(token.transfer(To, TokenAmount));
        require(GrowdropToken.transfer(To, GrowdropTokenAmount));
    }
    
    function EndGrowdrop() private {
        require(GrowdropStart && GrowdropEndTime<=now);
        if(!GrowdropOver) {
            
            //change state
            GrowdropOver=true;
            address owner=manager.Owner();
            
            require(CToken.balanceOf(address(this))>=TotalCTokenAmount);
            require(CToken.transfer(owner, CToken.balanceOf(address(this))-TotalCTokenAmount));
            
            //store last exchangeRateStored to calculate
            ExchangeRateOver = CToken.exchangeRateCurrent();
            //redeem all ctoken balance of Growdrop contract, and there will be no more interests from Growdrop contract
            require(CToken.redeem(TotalCTokenAmount)==0);
            
            uint256 calculatedBalance = MulAndDiv(TotalCTokenAmount, ExchangeRateOver, ConstVal);
            
            require(Token.balanceOf(address(this))>=calculatedBalance);
            require(Token.transfer(owner, Token.balanceOf(address(this))-calculatedBalance));
            //store last interests to calculate
            require(calculatedBalance>=TotalMintedAmount);
            TotalInterestOver = calculatedBalance-TotalMintedAmount;
            
            //event
            require(manager.emitGrowdropActionEvent(true, now));
        }
    }
    
    function AddToUniswap(uint256 TokenAmount) private {
        address newTokenExchangeAddr = UniswapFactory.getExchange(address(GrowdropToken)); 
        if(newTokenExchangeAddr==address(0x0)) {
            newTokenExchangeAddr = UniswapFactory.createExchange(address(GrowdropToken));
        }
        UniswapNewTokenExchange = UniswapExchangeInterface(newTokenExchangeAddr);
        
        //only for kovan
        UniswapDaiSwapInterface UniswapDaiSwap=UniswapDaiSwapInterface(0xDEe497AD02186Ea1f87D176f4028a9aB0193e444);
        require(Token.approve(address(UniswapDaiSwap), TokenAmount));
        TokenAmount = UniswapDaiSwap.swapDAICompoundToKyber(TokenAmount);
        //
        
        uint256 minConversionRate;
        uint256 slippageRate;
        (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(KyberToken, EthToken, TokenAmount);
        uint256 TokenToEthAmount = MulAndDiv(minConversionRate, TokenAmount, ConstVal);
        if(TokenToEthAmount<=KyberMinimum || slippageRate == 0) {
            sendTokenInWithdraw(KyberToken, Beneficiary, TokenAmount, ToUniswapTokenAmount);
            return;
        }
        
        uint256 min_liquidity;
        uint256 eth_reserve = address(UniswapNewTokenExchange).balance;
        uint256 total_liquidity = UniswapNewTokenExchange.totalSupply();
        
        if (total_liquidity==0) {
            min_liquidity = eth_reserve+TokenToEthAmount;
            require(min_liquidity>=TokenToEthAmount);
            changeTokenToEth_AddLiquidity_Transfer(minConversionRate, TokenAmount, TokenToEthAmount,min_liquidity,ToUniswapTokenAmount);
        } else {
            uint256 max_token;
            uint256 token_reserve = GrowdropToken.balanceOf(address(UniswapNewTokenExchange));
            max_token = MulAndDiv(TokenToEthAmount, token_reserve, eth_reserve)+1;
            require(max_token>1);
            min_liquidity = MulAndDiv(TokenToEthAmount, total_liquidity, eth_reserve);
            if(max_token>ToUniswapTokenAmount) {
                addLiquidityAndTransferLower(eth_reserve,token_reserve,total_liquidity,TokenAmount);
            } else {
                
                changeTokenToEth_AddLiquidity_Transfer(minConversionRate, TokenAmount, TokenToEthAmount,min_liquidity,max_token);
                require(GrowdropToken.transfer(Beneficiary, ToUniswapTokenAmount-max_token));
            }
        }
    }
    
    function addLiquidityAndTransferLower(uint256 eth_reserve, uint256 token_reserve, uint256 total_liquidity, uint256 TokenAmount) private {
        uint256 lowerEthAmount = MulAndDiv(ToUniswapTokenAmount-1, eth_reserve, token_reserve);
        uint256 max_token = MulAndDiv(lowerEthAmount, token_reserve, eth_reserve)+1;
        require(max_token>1);
        uint256 min_liquidity = MulAndDiv(lowerEthAmount, total_liquidity, eth_reserve);
        
        uint256 lowerTokenAmount;
        uint256 minConversionRate;
        if(lowerEthAmount<=KyberMinimum) {
            (minConversionRate, lowerTokenAmount) = calculateTokenAmountByEthAmount(KyberMinimum);
        } else {
            (minConversionRate, lowerTokenAmount) = calculateTokenAmountByEthAmount(lowerEthAmount);
        }
        if(minConversionRate==0) {
            sendTokenInWithdraw(KyberToken, Beneficiary, TokenAmount, ToUniswapTokenAmount);
            return;
        }
        
        changeTokenToEth_AddLiquidity_Transfer(minConversionRate, lowerTokenAmount, lowerEthAmount, min_liquidity, max_token);
        
        if(KyberMinimum>=lowerEthAmount) {
            address(uint160(Beneficiary)).transfer(KyberMinimum-lowerEthAmount);
        }
        sendTokenInWithdraw(KyberToken, Beneficiary, TokenAmount-lowerTokenAmount, ToUniswapTokenAmount-max_token);
    }
    
    function calculateTokenAmountByEthAmount(uint256 lowerEthAmount) public view returns (uint256, uint256) {
        uint256 minConversionRate;
        uint256 slippageRate;
        (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(KyberToken, EthToken, ConstVal);
        
        uint256 ConstValminConversionRate=minConversionRate;
        uint256 lowerTokenAmount = MulAndDiv(lowerEthAmount, ConstVal, minConversionRate);
        
        (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(KyberToken, EthToken, lowerTokenAmount);
        if(slippageRate==0) {
            return (0, 0);
        }
        
        uint256 approximateLowerEth = MulAndDiv(lowerTokenAmount,minConversionRate,ConstVal);
        uint256 reapproximateEth=lowerEthAmount*2;
        require(reapproximateEth/2==lowerEthAmount && reapproximateEth>=approximateLowerEth);
        
        lowerTokenAmount = MulAndDiv(reapproximateEth-approximateLowerEth, ConstVal, ConstValminConversionRate);
        (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(KyberToken, EthToken, lowerTokenAmount);
        reapproximateEth=MulAndDiv(lowerTokenAmount, minConversionRate, ConstVal);
        
        if(slippageRate==0 || reapproximateEth<=KyberMinimum) {
            return (0, 0);
        }
        return (minConversionRate, lowerTokenAmount);
    }
    
    function changeTokenToEth_AddLiquidity_Transfer(uint256 minConversionRate, uint256 tokenAmount, uint256 ethAmount, uint256 liquidity, uint256 max_token) private {
        require(KyberToken.approve(address(KyberNetworkProxy), tokenAmount));
        uint destAmount = KyberNetworkProxy.swapTokenToEther(KyberToken, tokenAmount, minConversionRate);
        address(uint160(Beneficiary)).transfer(destAmount-MulAndDiv(minConversionRate, tokenAmount, ConstVal));
        
        require(GrowdropToken.approve(address(UniswapNewTokenExchange),max_token));
        require(liquidity==UniswapNewTokenExchange.addLiquidity.value(ethAmount)(liquidity,max_token,1739591241));
        require(UniswapNewTokenExchange.transfer(Beneficiary, liquidity));
    }
    
    function TotalBalance() public view returns (uint256) {
        if(GrowdropOver) {
            require(TotalInterestOver+TotalMintedAmount>=TotalMintedAmount);
            return TotalInterestOver+TotalMintedAmount;
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
        require(TotalPerAddress(Investor)>=InvestAmountPerAddress[Investor]);
        uint256 InterestPerAddress = TotalPerAddress(Investor)-InvestAmountPerAddress[Investor];
        if(GrowdropOver) {
            return MulAndDiv(InterestPerAddress, ConstVal, TotalInterestOver);
        }
        require(TotalBalance()>=TotalMintedAmount);
        return MulAndDiv(InterestPerAddress, ConstVal, TotalBalance()-TotalMintedAmount);
    }
    
    function MulAndDiv(uint256 a, uint256 b, uint256 c) private pure returns (uint256) {
        uint256 temp = a*b;
        require(temp/b==a);
        require(c>0);
        return temp/c;
    }
    
    function () external payable {
        
    }
}
