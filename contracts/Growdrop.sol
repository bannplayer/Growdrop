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
    uint256 constant Minimum=10**14;
    
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
        GrowdropAmount = _GrowdropAmount;
        
        require(GrowdropPeriod>0);
        GrowdropEndTime = GrowdropPeriod;
        
        manager = GrowdropManagerInterface(msg.sender);
        
        require(_ToUniswapInterestRate>0 && _ToUniswapInterestRate<98);
        require(_ToUniswapTokenAmount>Minimum && _GrowdropAmount>Minimum);
        require(_GrowdropAmount+_ToUniswapTokenAmount>_ToUniswapTokenAmount);
        ToUniswapTokenAmount = _ToUniswapTokenAmount;
        ToUniswapInterestRate = _ToUniswapInterestRate;
        
        DonateId = _DonateId;
        
        //kovan address
        KyberToken = EIP20Interface(0xC4375B7De8af5a38a93548eb8453a498222C4fF2);
    }
    
    function StartGrowdrop() public {
        require(msg.sender==Beneficiary);
        require(!GrowdropStart);
        GrowdropStart = true;
        
        if(DonateId==0) {
            require(GrowdropToken.transferFrom(msg.sender, address(this), GrowdropAmount+ToUniswapTokenAmount));
        }

        GrowdropStartTime = now;
        
        GrowdropEndTime = Add(GrowdropEndTime,now);
        
        require(manager.emitGrowdropActionEvent(address(0x0), 0, now, 5, 0));
    }
    
    function Mint(uint256 Amount) public {
        require(GrowdropStart);
        require(now<GrowdropEndTime);
        require(msg.sender!=Beneficiary);
        require(Amount>Minimum);
        
        uint256 _exchangeRateCurrent = CToken.exchangeRateCurrent();
        uint256 _ctoken;
        uint256 _toMinAmount;
        (_ctoken, _toMinAmount) = toMinAmount(Amount, _exchangeRateCurrent);
        require(Token.transferFrom(msg.sender, address(this), _toMinAmount));
        require(Token.approve(address(CToken), _toMinAmount));
        require(CToken.mint(_toMinAmount)==0);
        
        CTokenPerAddress[msg.sender] = Add(CTokenPerAddress[msg.sender], _ctoken);
        TotalCTokenAmount = Add(TotalCTokenAmount, _ctoken);

        InvestAmountPerAddress[msg.sender] = Add(InvestAmountPerAddress[msg.sender], _toMinAmount);
        TotalMintedAmount = Add(TotalMintedAmount, _toMinAmount);
        
        if(!manager.CheckUserJoinedGrowdrop(address(this),msg.sender)) {
            require(manager.emitGrowdropActionEvent(msg.sender, 0, now, 4, 0));
        }
        require(manager.emitGrowdropActionEvent(msg.sender, InvestAmountPerAddress[msg.sender], now, 0, _toMinAmount));
    }
    
    function Redeem(uint256 Amount) public {
        require(GrowdropStart);
        require(now<GrowdropEndTime);
        require(msg.sender!=Beneficiary);
        require(Amount>Minimum || Amount==0);
        
        if(Amount==0) {
            Amount = InvestAmountPerAddress[msg.sender];
        }

        uint256 _exchangeRateCurrent = CToken.exchangeRateCurrent();
        uint256 _ctoken;
        uint256 _toMaxAmount;
        (_ctoken, _toMaxAmount) = toMaxAmount(Amount, _exchangeRateCurrent);
        require(_ctoken<=MulAndDiv(InvestAmountPerAddress[msg.sender], ConstVal, _exchangeRateCurrent));
        require(CToken.redeemUnderlying(_toMaxAmount)==0);
        require(Token.transfer(msg.sender, _toMaxAmount));
        
        CTokenPerAddress[msg.sender] = Sub(CTokenPerAddress[msg.sender], _ctoken);
        TotalCTokenAmount = Sub(TotalCTokenAmount,_ctoken);

        uint256 _toMinAmount;
        (,_toMinAmount) = toMinAmount(Amount, _exchangeRateCurrent);

        InvestAmountPerAddress[msg.sender] = Sub(InvestAmountPerAddress[msg.sender], _toMinAmount);
        TotalMintedAmount = Sub(TotalMintedAmount, _toMinAmount);

        require(manager.emitGrowdropActionEvent(msg.sender, InvestAmountPerAddress[msg.sender], now, 1, _toMinAmount));
    }
    
    function Withdraw(bool ToUniswap) public {
        require(!WithdrawOver[msg.sender]);
        
        WithdrawOver[msg.sender] = true;
        
        EndGrowdrop();
        if(TotalCTokenAmount==0) {
            return;
        }
        if(DonateId!=0) {
            ToUniswap = false;
        }
        if(msg.sender==Beneficiary) {
            uint256 OwnerFee = MulAndDiv(TotalInterestOver, 3, 100);
            if(ToUniswap) {
                uint256 ToUniswapInterestRateCalculated = MulAndDiv(TotalInterestOver, ToUniswapInterestRate, 100);
                require(Token.transfer(Beneficiary, Sub(Sub(TotalInterestOver,ToUniswapInterestRateCalculated),OwnerFee)));
                
                require(Token.approve(address(manager.Tokenswap()), ToUniswapInterestRateCalculated));
                uint256 swappedTokenAmount = manager.Tokenswap().uniswapToken(address(Token),address(KyberToken),ToUniswapInterestRateCalculated);
                
                require(KyberToken.approve(address(manager.Tokenswap()), swappedTokenAmount));
                require(GrowdropToken.approve(address(manager.Tokenswap()), ToUniswapTokenAmount));
                manager.Tokenswap().addPoolToUniswap(address(KyberToken), address(GrowdropToken), Beneficiary, swappedTokenAmount, ToUniswapTokenAmount);
            } else {
                if(DonateId==0) {
                    sendTokenInWithdraw(Beneficiary, Sub(TotalInterestOver, OwnerFee), ToUniswapTokenAmount);
                } else {
                    Token.transfer(Beneficiary, Sub(TotalInterestOver,OwnerFee));
                }
            }
            require(Token.transfer(manager.Owner(), OwnerFee));
            
            require(manager.emitGrowdropActionEvent(msg.sender, 0, now, 2, 0));
        } else {
            uint256 investorTotalAmount = MulAndDiv(CTokenPerAddress[msg.sender], ExchangeRateOver, ConstVal);
            uint256 investorTotalInterest = Sub(investorTotalAmount, InvestAmountPerAddress[msg.sender]);
            uint256 tokenByInterest = MulAndDiv(
                GrowdropAmount,
                investorTotalInterest,
                TotalInterestOver
            );
            if(DonateId!=0) tokenByInterest = investorTotalInterest;
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
            GrowdropOver = true;
            address owner = manager.Owner();
            
            require(CToken.transfer(owner, Sub(CToken.balanceOf(address(this)),TotalCTokenAmount)));
            
            ExchangeRateOver = CToken.exchangeRateCurrent();
            uint256 _toAmount = MulAndDiv(Add(TotalCTokenAmount,1), ExchangeRateOver, ConstVal);

            if(TotalCTokenAmount==0) {
                if(DonateId==0) {
                    require(GrowdropToken.transfer(Beneficiary, Add(GrowdropAmount, ToUniswapTokenAmount)));
                }
            } else {
                require(CToken.redeemUnderlying(_toAmount)==0);
            }
            
            require(Token.transfer(owner, Sub(Token.balanceOf(address(this)),_toAmount)));
            TotalInterestOver = Sub(_toAmount, TotalMintedAmount);
            
            require(manager.emitGrowdropActionEvent(address(0x0), 0, now, 6, 0));
        }
    }

    function toMaxAmount(uint256 tokenAmount, uint256 exchangeRate) private pure returns (uint256, uint256) {
        uint256 _ctoken = MulAndDiv(tokenAmount, 10**18, exchangeRate);
        return (_ctoken, MulAndDiv(
            Add(_ctoken, 1),
            exchangeRate,
            10**18
        ));
    }

    function toMinAmount(uint256 tokenAmount, uint256 exchangeRate) private pure returns (uint256, uint256) {
        uint256 _ctoken = MulAndDiv(tokenAmount, 10**18, exchangeRate);
        return (_ctoken, Add(
            MulAndDiv(
                _ctoken,
                exchangeRate,
                10**18
            ),
            1
        ));
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