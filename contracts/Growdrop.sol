pragma solidity ^0.5.11;

import "./EIP20Interface.sol";
import "./CTokenInterface.sol";
import "./GrowdropManagerInterface.sol";
import "./UniswapFactoryInterface.sol";
import "./UniswapExchangeInterface.sol";
import "./KyberNetworkProxyInterface.sol";
import "./TokenswapInterface.sol";

contract Growdrop {

    GrowdropManagerInterface public manager;
    
    EIP20Interface public Token;
    
    EIP20Interface public GrowdropToken;
    
    CTokenInterface public CToken;
    
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
    
    uint256 public DonateId;
    
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
        uint256 _DonateId) public {
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
        require(_GrowdropAmount+_ToUniswapTokenAmount>_ToUniswapTokenAmount);
        ToUniswapTokenAmount=_ToUniswapTokenAmount;
        ToUniswapInterestRate=_ToUniswapInterestRate;
        
        DonateId=_DonateId;
        
        //kovan address
        KyberToken = EIP20Interface(0xC4375B7De8af5a38a93548eb8453a498222C4fF2);
    }
    
    function StartGrowdrop() public {
        require(msg.sender==Beneficiary);
        require(!GrowdropStart);
        GrowdropStart=true;
        
        if(DonateId==0) {
            require(GrowdropToken.transferFrom(msg.sender, address(this), GrowdropAmount+ToUniswapTokenAmount));
        }

        GrowdropStartTime=now;
        
        GrowdropEndTime=Add(GrowdropEndTime,now);
        
        require(manager.emitGrowdropActionEvent(address(0x0), 0, now, 5, 0));
    }
    
    function Mint(uint256 Amount) public {
        require(GrowdropStart);
        require(now<GrowdropEndTime);
        require(msg.sender!=Beneficiary);
        require(Amount>0);
        
        require(Token.transferFrom(msg.sender, address(this), Amount));
        
        InvestAmountPerAddress[msg.sender]=Add(InvestAmountPerAddress[msg.sender],Amount);
        
        TotalMintedAmount=Add(TotalMintedAmount,Amount);
        
        uint256 beforeBalance = CToken.balanceOf(address(this));
        
        require(Token.approve(address(CToken), Amount));
        
        require(CToken.mint(Amount)==0);
        
        
        uint256 BalanceDif = CToken.balanceOf(address(this))-beforeBalance;
        require(BalanceDif>0);
        
        CTokenPerAddress[msg.sender]+=BalanceDif;
        TotalCTokenAmount=Add(TotalCTokenAmount, BalanceDif);
        
        if(!manager.CheckUserJoinedGrowdrop(address(this),msg.sender)) {
            require(manager.emitGrowdropActionEvent(msg.sender, 0, now, 4, 0));
        }
        require(manager.emitGrowdropActionEvent(msg.sender, InvestAmountPerAddress[msg.sender], now, 0, Amount));
    }
    
    function Redeem(uint256 Amount) public {
        require(GrowdropStart);
        require(now<GrowdropEndTime);
        require(msg.sender!=Beneficiary);
        require(Amount>0);
        
        InvestAmountPerAddress[msg.sender]=Sub(InvestAmountPerAddress[msg.sender],Amount);
        
        TotalMintedAmount-=Amount;
        
        uint256 beforeBalance = CToken.balanceOf(address(this));
        
        require(CToken.redeemUnderlying(Amount)==0);
        
        require(Token.transfer(msg.sender, Amount));
        
        require(beforeBalance>CToken.balanceOf(address(this)));
        uint256 BalanceDif = beforeBalance-CToken.balanceOf(address(this));
        
        CTokenPerAddress[msg.sender]-=BalanceDif;
        TotalCTokenAmount-=BalanceDif;
        
        require(manager.emitGrowdropActionEvent(msg.sender, InvestAmountPerAddress[msg.sender], now, 1, Amount));
    }
    
    function Withdraw(bool ToUniswap) public {
        require(!WithdrawOver[msg.sender]);
        
        WithdrawOver[msg.sender]=true;
        
        EndGrowdrop();
        if(DonateId!=0) {
            ToUniswap=false;
        }
        
        if(msg.sender==Beneficiary) {
            uint256 OwnerFee=MulAndDiv(TotalInterestOver, 3, 100);
            if(ToUniswap) {
                uint256 ToUniswapInterestRateCalculated = MulAndDiv(TotalInterestOver, ToUniswapInterestRate, 100);
                require(Token.transfer(Beneficiary, TotalInterestOver-ToUniswapInterestRateCalculated-OwnerFee));
                
                require(Token.approve(address(manager.Tokenswap()), ToUniswapInterestRateCalculated));
                uint256 swappedTokenAmount = manager.Tokenswap().uniswapToken(address(Token),address(KyberToken),ToUniswapInterestRateCalculated);
                
                require(KyberToken.approve(address(manager.Tokenswap()), swappedTokenAmount));
                require(GrowdropToken.approve(address(manager.Tokenswap()), ToUniswapTokenAmount));
                manager.Tokenswap().addPoolToUniswap(address(KyberToken), address(GrowdropToken), Beneficiary, swappedTokenAmount, ToUniswapTokenAmount);
            } else {
                if(DonateId==0) {
                    sendTokenInWithdraw(Beneficiary, TotalInterestOver-OwnerFee, ToUniswapTokenAmount);
                } else {
                    Token.transfer(Beneficiary, TotalInterestOver-OwnerFee);
                }
            }
            require(Token.transfer(manager.Owner(), OwnerFee));
            
            require(manager.emitGrowdropActionEvent(msg.sender, 0, now, 2, 0));
        } else {
            uint256 tokenByInterest = MulAndDiv(InterestRate(msg.sender), GrowdropAmount, ConstVal);
            if(DonateId!=0) tokenByInterest = Sub(TotalPerAddress(msg.sender),InvestAmountPerAddress[msg.sender]);
            sendTokenInWithdraw(msg.sender, InvestAmountPerAddress[msg.sender], tokenByInterest);
            require(manager.emitGrowdropActionEvent(msg.sender, tokenByInterest, now, 3, InvestAmountPerAddress[msg.sender]));
        }
    }
    
    function sendTokenInWithdraw(address To, uint256 TokenAmount, uint256 GrowdropTokenAmount) private {
        require(Token.transfer(To, TokenAmount));
        if(DonateId==0) {
            require(GrowdropToken.transfer(To, GrowdropTokenAmount));
        } else {
            manager.DonateToken().mint(msg.sender, Beneficiary, address(Token), GrowdropTokenAmount, DonateId);
        }
    }
    
    function EndGrowdrop() private {
        require(GrowdropStart && GrowdropEndTime<=now);
        if(!GrowdropOver) {
            
            GrowdropOver=true;
            if(TotalCTokenAmount==0) {
                require(GrowdropToken.transfer(Beneficiary, GrowdropTokenAmount+ToUniswapTokenAmount));
                require(manager.emitGrowdropActionEvent(address(0x0), 0, now, 6, 0));
                return;
            }
            address owner=manager.Owner();
            
            require(CToken.transfer(owner, CToken.balanceOf(address(this))-TotalCTokenAmount));
            
            ExchangeRateOver = CToken.exchangeRateCurrent();
            require(CToken.redeem(TotalCTokenAmount)==0);
            
            uint256 calculatedBalance = MulAndDiv(TotalCTokenAmount, ExchangeRateOver, ConstVal);
            
            require(Token.transfer(owner, Token.balanceOf(address(this))-calculatedBalance));
            TotalInterestOver = calculatedBalance-TotalMintedAmount;
            
            require(manager.emitGrowdropActionEvent(address(0x0), 0, now, 6, 0));
        }
    }
    
    function TotalBalance() public view returns (uint256) {
        if(GrowdropOver) {
            return Add(TotalInterestOver,TotalMintedAmount);
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
        uint256 InterestPerAddress = Sub(TotalPerAddress(Investor),InvestAmountPerAddress[Investor]);
        if(GrowdropOver) {
            return MulAndDiv(InterestPerAddress, ConstVal, TotalInterestOver);
        }
        return MulAndDiv(InterestPerAddress, ConstVal, Sub(TotalBalance(),TotalMintedAmount));
    }
    
    function MulAndDiv(uint256 a, uint256 b, uint256 c) private pure returns (uint256) {
        uint256 temp = a*b;
        require(temp/b==a);
        require(c>0);
        return temp/c;
    }
    
    function Add(uint256 a, uint256 b) private pure returns (uint256) {
        require(a+b>=a);
        return a+b;
    }
    
    function Sub(uint256 a, uint256 b) private pure returns (uint256) {
        require(a>=b);
        return a-b;
    }
    
    function () external payable {
        
    }
}
