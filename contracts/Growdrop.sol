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
    mapping(address => uint256) public TokenPerAddress;
    
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
    
    //for calculation
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
        GrowdropEndTime=GrowdropStartTime+GrowdropPeriod;
        manager=GrowdropManager(msg.sender);
        UniswapFactory = UniswapFactoryInterface(UniswapFactoryAddr);
        UniswapDaiExchange=UniswapExchangeInterface(UniswapDaiExchangeAddr);
        require(_ToUniswapInterestRate>0 && _ToUniswapInterestRate<100);
        ToUniswapTokenAmount=_ToUniswapTokenAmount;
        ToUniswapInterestRate=_ToUniswapInterestRate;
    }
    
    //start Growdrop
    //beneficiary will send tokens to give investors and Growdrop contract get tokens 
    function StartGrowdrop() public returns (bool) {
        require(msg.sender==Beneficiary);
        require(GrowdropStart==false);
        GrowdropStart=true;
        
        //need to approve from msg.sender to this contract first
        require(GrowdropToken.transferFrom(msg.sender, address(this), GrowdropAmount+ToUniswapTokenAmount)==true);
        
        uint256 period = GrowdropEndTime.sub(GrowdropStartTime);

        //Growdrop start time is now
        GrowdropStartTime=now;
        
        //Growdrop ends now+GrowdropTime
        GrowdropEndTime=now + period;
        
        //event
        require(manager.emitGrowdropActionEvent(false, GrowdropStartTime)==true);
        return true;
    }
    
    //investor mint token and Growdrop contract gets interests (not only once, can mint over time)
    function Mint(uint256 Amount) public returns (bool) {
        require(GrowdropStart==true);
        require(now<GrowdropEndTime);
        require(msg.sender!=Beneficiary);
        
        //need to approve from msg.sender to this contract first
        require(Token.transferFrom(msg.sender, address(this), Amount)==true);
        
        //investor's minted token balance increases 
        InvestAmountPerAddress[msg.sender]=InvestAmountPerAddress[msg.sender].add(Amount);
        
        //total minted token balance increases
        TotalMintedAmount=TotalMintedAmount.add(Amount);
        
        //Growdrop contract's balanceOf ctoken before mint
        uint256 beforeBalance = CToken.balanceOf(address(this));
        
        //first approve to mint
        require(Token.approve(address(CToken), Amount)==true);
        
        //mint ctoken ( ex) compound mint )  
        require(CToken.mint(Amount)==0);
        
        //Growdrop contract's balanceOf ctoken after mint
        uint256 currentBalance = CToken.balanceOf(address(this));
        
        //investor's balanceOf ctoken increases
        TokenPerAddress[msg.sender]=TokenPerAddress[msg.sender].add(currentBalance.sub(beforeBalance));
        
        //event
        if(manager.CheckUserJoinedGrowdrop(address(this),msg.sender)==false) {
            require(manager.emitUserActionEvent(msg.sender, 0, now, 4, 0)==true);
        }
        require(manager.emitUserActionEvent(msg.sender, Amount, now, 0, 0)==true);
        return true;
    }
    
    //investor redeem token and Growdrop contract gives token to investor, investor cannot get interests (not only once, can redeem over time)
    function Redeem(uint256 Amount) public returns (bool) {
        require(GrowdropStart==true);
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
        require(CToken.redeemUnderlying(Amount)==0, "redeem from CToken failed");
        
        //transfer redeemed token balance to investor
        require(Token.transfer(msg.sender, Amount)==true);
        
        //Growdrop contract's balanceOf ctoken after redeem
        uint256 currentBalance = CToken.balanceOf(address(this));
        
        //investor's balanceOf ctoken decreases
        TokenPerAddress[msg.sender]=TokenPerAddress[msg.sender].sub(beforeBalance.sub(currentBalance));
        
        //event
        require(manager.emitUserActionEvent(msg.sender, Amount, now, 1, 0)==true);
        return true;
    }
    
    //after Growdrop, anyone can withdraw all interests from Growdrop contract to beneficiary
    function Withdraw(bool ToUniswap) public returns (bool) {
        //beneficiary can get interests only once 
        require(WithdrawOver[msg.sender]==false);
        
        //change state
        WithdrawOver[msg.sender]=true;
        
        EndGrowdrop();
        
        if(msg.sender==Beneficiary) {
            uint256 OwnerFee=TotalInterestOver.div(100);
            if(ToUniswap) {
                //transfer all interests to beneficiary
                uint256 ToUniswapInterestRateCalculated = TotalInterestOver.mul(ToUniswapInterestRate).div(100);
                require(Token.transfer(Beneficiary, TotalInterestOver.sub(ToUniswapInterestRateCalculated).sub(OwnerFee))==true);
            
                if(AddToUniswap(ToUniswapInterestRateCalculated, ToUniswapTokenAmount)==false) {
                    require(sendTokenInWithdraw(Beneficiary, ToUniswapInterestRateCalculated, ToUniswapTokenAmount)==true);
                }
                require(manager.emitUniswapAddedEvent(address(GrowdropToken), ToUniswapInterestRateCalculated, ToUniswapTokenAmount, now)==true);
            } else {
                require(sendTokenInWithdraw(Beneficiary, TotalInterestOver.sub(OwnerFee), ToUniswapTokenAmount)==true);
            }
            require(Token.transfer(manager.Owner(), OwnerFee)==true);
            
            //event
            require(manager.emitUserActionEvent(msg.sender, 0, now, 2, 0)==true);
        } else {
            require(sendTokenInWithdraw(msg.sender, InvestAmountPerAddress[msg.sender], TokenByInterest(msg.sender))==true);
            //event
            require(manager.emitUserActionEvent(msg.sender, TokenByInterest(msg.sender), now, 3, InvestAmountPerAddress[msg.sender])==true);
        }
        return true;
    }
    
    function sendTokenInWithdraw(address To, uint256 TokenAmount, uint256 GrowdropTokenAmount) private returns (bool) {
        require(Token.transfer(To, TokenAmount)==true);
        require(GrowdropToken.transfer(To, GrowdropTokenAmount)==true);
        return true;
    }
    
    function EndGrowdrop() public {
        require(GrowdropStart==true && GrowdropEndTime<=now);
        if(!GrowdropOver) {
            
            //change state
            GrowdropOver=true;
            
            //redeem all ctoken balance of Growdrop contract, and there will be no more interests from Growdrop contract
            require(CToken.redeem(CToken.balanceOf(address(this)))==0);
            
            //store last exchangeRateStored to calculate
            ExchangeRateOver = CToken.exchangeRateStored();
            
            //store last interests to calculate
            TotalInterestOver = Token.balanceOf(address(this)).sub(TotalMintedAmount);
            
            //event
            require(manager.emitGrowdropActionEvent(true, now)==true);
        }
    }
    
    function AddToUniswap(uint256 daiAmount, uint256 newTokenAmount) private returns (bool) {
        UniswapExchangeInterface newTokenExchange = UniswapExchangeInterface(UniswapFactory.getExchange(address(GrowdropToken))); 
        if(address(newTokenExchange)==address(0x0)) {
            newTokenExchange = UniswapExchangeInterface(UniswapFactory.createExchange(address(GrowdropToken)));
        }
        
        uint256 daiToEthAmount = UniswapDaiExchange.getTokenToEthInputPrice(daiAmount);
        if(daiToEthAmount<1000000000) {
            return false;
        }
        
        uint256 max_token=0;
        uint256 min_liquidity=0;
        if (newTokenExchange.totalSupply()==0) {
            changeDaiToEth(daiAmount, daiToEthAmount);
            min_liquidity = address(newTokenExchange).balance.add(daiToEthAmount);
            addLiquidityAndTransfer(daiToEthAmount,min_liquidity,newTokenAmount,newTokenExchange);
        } else {
            uint256 eth_reserve = address(newTokenExchange).balance;
            uint256 token_reserve = GrowdropToken.balanceOf(address(newTokenExchange));
            uint256 total_liquidity = newTokenExchange.totalSupply();
            max_token = daiToEthAmount.mul(token_reserve).div(eth_reserve).add(1);
            min_liquidity = daiToEthAmount.mul(total_liquidity).div(eth_reserve);
            if(max_token>newTokenAmount) {
                return addLiquidityAndTransferLower(eth_reserve,token_reserve,total_liquidity,newTokenAmount,daiAmount,newTokenExchange);
            } else {
                changeDaiToEth(daiAmount, daiToEthAmount);
                addLiquidityAndTransfer(daiToEthAmount,min_liquidity,max_token,newTokenExchange);
                require(GrowdropToken.transfer(Beneficiary, newTokenAmount-max_token)==true);
            }
        }
        return true;
    }
    
    function addLiquidityAndTransferLower(uint256 eth_reserve, uint256 token_reserve, uint256 total_liquidity, uint256 newTokenAmount, uint256 daiAmount, UniswapExchangeInterface tokenExchange) private returns (bool) {
        uint256 lowerEthAmount = newTokenAmount.sub(1).mul(eth_reserve).div(token_reserve);
        if(lowerEthAmount<1000000000) {
            return false;
        }
        uint256 max_token = lowerEthAmount.mul(token_reserve).div(eth_reserve).add(1);
        uint256 min_liquidity = lowerEthAmount.mul(total_liquidity).div(eth_reserve);
                
        uint256 lowerDaiAmount = UniswapDaiExchange.getTokenToEthOutputPrice(lowerEthAmount);
        changeDaiToEth(lowerDaiAmount, lowerEthAmount);
        addLiquidityAndTransfer(lowerEthAmount, min_liquidity, max_token, tokenExchange);
        require(sendTokenInWithdraw(Beneficiary, daiAmount.sub(lowerDaiAmount), newTokenAmount.sub(max_token))==true);
        return true;
    }
    
    function addLiquidityAndTransfer(uint256 ethAmount, uint256 liquidity, uint256 tokenAmount, UniswapExchangeInterface tokenExchange) private returns (uint256) {
        require(GrowdropToken.approve(address(tokenExchange),tokenAmount)==true);
        require(liquidity==tokenExchange.addLiquidity.value(ethAmount)(liquidity,tokenAmount,1739591241));
        require(tokenExchange.transfer(Beneficiary, liquidity)==true);
        return liquidity;
    }
    
    function changeDaiToEth(uint256 daiAmount, uint256 daiToEthAmount) private returns (uint256) {
        require(Token.approve(address(UniswapDaiExchange), daiAmount)==true);
        require(daiToEthAmount==UniswapDaiExchange.tokenToEthTransferInput(daiAmount, daiToEthAmount, 1739591241, address(this)));
        return daiToEthAmount;
    }
    
    
    //calculate function
    
    //Growdrop contract's total balance ( minted token balance + interests,  ex) compound balanceOfUnderlying )
    //ctoken balanceOf Growdrop contract * ctoken exchangeRateStored / 10^18
    function TotalBalance() public view returns (uint256) {
        return CToken.balanceOf(address(this)).mul(CToken.exchangeRateStored()).div(ConstVal);
    }
    
    //investor's total balance ( minted token balance + interests, ex) compound balanceOfUnderlying )
    //ctoken balanceOf investor * ctoken exchangeRateStored / 10^18
    function TotalPerAddress(address Investor) public view returns (uint256) {
        if(GrowdropOver) {
            return TokenPerAddress[Investor].mul(ExchangeRateOver).div(ConstVal);
        }
        return TokenPerAddress[Investor].mul(CToken.exchangeRateStored()).div(ConstVal);
    }
    
    //rate of investor's interests calculated by Growdrop contract's interests
    //investor's interests * 10^18 / Growdrop contract's interests
    function InterestRate(address Investor) public view returns (uint256) {
        if(GrowdropOver) {
            return TotalPerAddress(Investor).sub(InvestAmountPerAddress[Investor]).mul(ConstVal).div(TotalInterestOver);
        }
        return TotalPerAddress(Investor).sub(InvestAmountPerAddress[Investor]).mul(ConstVal).div(TotalBalance().sub(TotalMintedAmount));
    }
    
    //beneficiary's token balance that investor can get calculated by rate of investor's interests
    //rate of investor's interests * beneficiary's all token balance / 10^18 
    function TokenByInterest(address Investor) public view returns (uint256) {
        return InterestRate(Investor).mul(GrowdropAmount).div(ConstVal);
    }
    
    function getGrowdropData() public view returns (address, address, uint256, uint256, uint256, uint256, uint256, bool, bool, uint256, uint256) {
        if(GrowdropOver) {
            return (address(GrowdropToken), Beneficiary, GrowdropAmount, GrowdropStartTime, GrowdropEndTime, TotalInterestOver.add(TotalMintedAmount), TotalMintedAmount, GrowdropOver, GrowdropStart, ToUniswapTokenAmount, ToUniswapInterestRate);
        } else {
            return (address(GrowdropToken), Beneficiary, GrowdropAmount, GrowdropStartTime, GrowdropEndTime, TotalBalance(), TotalMintedAmount, GrowdropOver, GrowdropStart, ToUniswapTokenAmount, ToUniswapInterestRate);
        }
    }
    
    function getUserData() public view returns (uint256, uint256, uint256, uint256, uint256) {
        if(GrowdropOver) {
            return (InvestAmountPerAddress[msg.sender], TotalPerAddress(msg.sender), TotalPerAddress(msg.sender).sub(InvestAmountPerAddress[msg.sender]), InterestRate(msg.sender), TokenByInterest(msg.sender));
        }
        return (InvestAmountPerAddress[msg.sender], TotalPerAddress(msg.sender), TotalPerAddress(msg.sender).sub(InvestAmountPerAddress[msg.sender]), InterestRate(msg.sender), TokenByInterest(msg.sender));
    }
    
    function () external payable {
        
    }
}