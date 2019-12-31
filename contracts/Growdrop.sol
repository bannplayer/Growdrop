pragma solidity ^0.5.11;

import "./DonateTokenInterface.sol";
import "./EIP20Interface.sol";
import "./CTokenInterface.sol";
import "./UniswapFactoryInterface.sol";
import "./KyberNetworkProxyInterface.sol";
import "./TokenswapInterface.sol";

/**
 * @dev Implementation of Growdrop. from creating growdrop to starting, funding, refunding, ending, withdraw.
 */
contract Growdrop {
    
    /**
     * @notice Address to get owner fee from Growdrop.
     */
    address public owner;
    
    /**
     * @notice Check whether address is admin.
     */
    mapping(address => bool) public CheckOwner;
    
    /**
     * @notice Current DonateToken contract
     */
    DonateTokenInterface public DonateToken;
    
    /**
     * @notice Current Tokenswap contract
     */
    TokenswapInterface public Tokenswap;
    
    /**
     * @notice Growdrop's sequential number
     */
    uint256 public GrowdropCount;
    
    /**
     * @notice Growdrop event's sequential number
     */
    uint256 public EventIdx;
    
    /**
     * @notice Address of receiving accrued interest address by Growdrop's identifier
     */
    mapping(uint256 => address) public Beneficiary;
    
    /**
     * @notice Compound CToken amount per investor address by Growdrop's identifier
     */
    mapping(uint256 => mapping(address => uint256)) public CTokenPerAddress;
    
    /**
     * @notice Funded ERC20 token amount per investor address by Growdrop's identifier
     */
    mapping(uint256 => mapping(address => uint256)) public InvestAmountPerAddress;
    
    /**
     * @notice Actual amount per investor address by Growdrop's identifier
     */
    mapping(uint256 => mapping(address => uint256)) public ActualPerAddress;
    
    /**
     * @notice Actual Compound CToken amount per investor address by Growdrop's identifier
     */
    mapping(uint256 => mapping(address => uint256)) public ActualCTokenPerAddress;
    
    /**
     * @notice Check whether address withdrawn or not by Growdrop's identifier
     */
    mapping(uint256 => mapping(address => bool)) public WithdrawOver;
    
    /**
     * @notice ERC20 token amount to send to investors by Growdrop's identifier
     */
    mapping(uint256 => uint256) public GrowdropAmount;
    
    /**
     * @notice Growdrop's start timestamp by Growdrop's identifier
     */
    mapping(uint256 => uint256) public GrowdropStartTime;
    
    /**
     * @notice Growdrop's end timestamp by Growdrop's identifier
     */
    mapping(uint256 => uint256) public GrowdropEndTime;
    
    /**
     * @notice Growdrop's total funded ERC20 token amount by Growdrop's identifier
     */
    mapping(uint256 => uint256) public TotalMintedAmount;
    
    /**
     * @notice Growdrop's total Compound CToken amount by Growdrop's identifier
     */
    mapping(uint256 => uint256) public TotalCTokenAmount;
    
    /**
     * @notice Growdrop's total actual amount by Growdrop's identifier
     */
    mapping(uint256 => uint256) public TotalMintedActual;
    
    /**
     * @notice Growdrop's total actual Compound CToken amount by Growdrop's identifier
     */
    mapping(uint256 => uint256) public TotalCTokenActual;
    
    /**
     * @notice Compound's exchange rate when Growdrop is over by Growdrop's identifier
     */
    mapping(uint256 => uint256) public ExchangeRateOver;
    
    /**
     * @notice Growdrop's total accrued interest when Growdrop is over by Growdrop's identifier
     */
    mapping(uint256 => uint256) public TotalInterestOver;
    
    /**
     * @notice Growdrop's total actual accrued interest when Growdrop is over by Growdrop's identifier
     */
    mapping(uint256 => uint256) public TotalInterestOverActual;
    
    /**
     * @notice ERC20 token amount to add to UniswapExchange by Growdrop's identifier
     */
    mapping(uint256 => uint256) public ToUniswapTokenAmount;
    
    /**
     * @notice Percentage of Growdrop's total accrued interest to add to UniswapExchage by Growdrop's identifier
     */
    mapping(uint256 => uint256) public ToUniswapInterestRate;
    
    /**
     * @notice Check whether Growdrop is over by Growdrop's identifier
     */
    mapping(uint256 => bool) public GrowdropOver;
    
    /**
     * @notice Check whether Growdrop is started by Growdrop's identifier
     */
    mapping(uint256 => bool) public GrowdropStart;
    
    /**
     * @notice Growdrop's Donation identifier by Growdrop's identifier
     */
    mapping(uint256 => uint256) public DonateId;
    
    /**
     * @notice ERC20 Token to fund by Growdrop's identifier
     */
    mapping(uint256 => EIP20Interface) public Token;
    
    /**
     * @notice ERC20 Token to send to investors by Growdrop's identifier
     */
    mapping(uint256 => EIP20Interface) public GrowdropToken;
    
    /**
     * @notice Compound CToken by Growdrop's identifier
     */
    mapping(uint256 => CTokenInterface) public CToken;
    
    /**
     * @notice Percentage of owner fee to get from Growdrop's total accrued interest by Growdrop's identifier
     */
    mapping(uint256 => uint256) public GrowdropOwnerFeePercent;
    
    /**
     * @notice Check whether Growdrop adds liquidity to UniswapExchange
     */
    mapping(uint256 => bool) public AddToUniswap;
    
    /**
     * @notice Current percentage of owner fee
     */
    uint256 public CurrentOwnerFeePercent;
    
    /**
     * @notice Total funded ERC20 token amount with investor address and ERC20 token address
     */
    mapping(address => mapping(address => uint256)) public TotalUserInvestedAmount;
    
    /**
     * @notice Event emitted when new Growdrop is created
     */
    event NewGrowdrop(
        uint256 indexed event_idx,
        uint256 indexed growdrop_count,
        address indexed from_address,
        uint256 timestamp
    );
    
    /**
     * @notice Event emitted when Growdrop's event occurred
     */
    event GrowdropAction(
        uint256 indexed event_idx,
        uint256 indexed growdrop_count,
        address indexed from_address,
        uint256 amount1,
        uint256 amount2,
        uint256 action_idx,
        uint256 timestamp
    );
    
    /**
     * @notice Event emitted when Growdrop's donation ERC721 token event occurred
     */
    event DonateAction(
        uint256 indexed event_idx,
        address indexed from_address,
        address indexed to_address,
        address supporter,
        address beneficiary,
        address token_address,
        uint256 donate_id,
        uint256 token_id,
        uint256 amount,
        uint256 action_idx,
        uint256 timestamp
    );
    
    /**
     * @dev Constructor, set 'owner' and set 'CurrentOwnerFeePercent'.
     */
    constructor () public {
        owner = msg.sender;
        CheckOwner[msg.sender] = true;
        CurrentOwnerFeePercent = 3;
    }
    
    /**
     * @dev Create new Growdrop.
     * Only Address that 'CheckOwner' is true can call.
     * 'GrowdropTokenAddr' cannot be tokens which is in Compound's available markets.
     * 
     * Emits {NewGrowdrop} event indicating Growdrop's identifier.
     * 
     * @param TokenAddr ERC20 token address to fund tokens
     * @param CTokenAddr Compound CToken address which is pair of 'TokenAddr'
     * @param GrowdropTokenAddr ERC20 token address to send tokens to investors
     * @param BeneficiaryAddr address to receive Growdrop's accrued interest amount
     * @param _GrowdropAmount ERC20 token amount to send to investors
     * @param GrowdropPeriod period timestamp to get funds
     * @param _ToUniswapTokenAmount ERC20 token amount to add to UniswapExchange. If project does not want to add liquidity to UniswapExchage at all, 0.
     * @param _ToUniswapInterestRate percentage of Growdrop's accrued interest amount to add liquidity to UniswapExchange. 
     * @param _DonateId Growdrop's donation identifier. If Growdrop is donation, not 0. else 0
     */
    function newGrowdrop(
        address TokenAddr,
        address CTokenAddr,
        address GrowdropTokenAddr,
        address BeneficiaryAddr,
        uint256 _GrowdropAmount,
        uint256 GrowdropPeriod,
        uint256 _ToUniswapTokenAmount,
        uint256 _ToUniswapInterestRate,
        uint256 _DonateId) public {

        require(CheckOwner[msg.sender]);
        require(DonateToken.DonateIdOwner(_DonateId)==BeneficiaryAddr || _DonateId==0);
        require(_ToUniswapTokenAmount==0 || (_ToUniswapInterestRate>0 && _ToUniswapInterestRate<101-CurrentOwnerFeePercent && _ToUniswapTokenAmount>1e4));
        require(_DonateId!=0 || _GrowdropAmount>1e6);
        Add(_GrowdropAmount,_ToUniswapTokenAmount);
        
        GrowdropCount += 1;
        GrowdropOwnerFeePercent[GrowdropCount] = CurrentOwnerFeePercent;
        AddToUniswap[GrowdropCount] = _ToUniswapTokenAmount==0 ? false : true;

        Token[GrowdropCount] = EIP20Interface(TokenAddr);
        CToken[GrowdropCount] = CTokenInterface(CTokenAddr);
        GrowdropToken[GrowdropCount] = EIP20Interface(GrowdropTokenAddr);
        Beneficiary[GrowdropCount] = BeneficiaryAddr;
        GrowdropAmount[GrowdropCount] = _GrowdropAmount;
        
        GrowdropEndTime[GrowdropCount] = GrowdropPeriod;
        
        ToUniswapTokenAmount[GrowdropCount] = _ToUniswapTokenAmount;
        ToUniswapInterestRate[GrowdropCount] = _ToUniswapInterestRate;
        
        DonateId[GrowdropCount] = _DonateId;

        EventIdx += 1;
        emit NewGrowdrop(EventIdx, GrowdropCount, BeneficiaryAddr, now);
    }
    
    /**
     * @dev Start Growdrop by Growdrop's identifier.
     * Only 'Beneficiary' address can call.
     * Transfers ERC20 token amount of 'GrowdropAmount' and 'ToUniswapTokenAmount' to this contract.
     * 
     * Emits {GrowdropAction} event indicating Growdrop's identifier and event information.
     * 
     * @param _GrowdropCount Growdrop's identifier
     */
    function StartGrowdrop(uint256 _GrowdropCount) public {
        require(msg.sender==Beneficiary[_GrowdropCount], "not beneficiary");
        require(!GrowdropStart[_GrowdropCount], "already started");
        GrowdropStart[_GrowdropCount] = true;
        
        if(DonateId[_GrowdropCount]==0) {
            require(GrowdropToken[_GrowdropCount].transferFrom(msg.sender, address(this), GrowdropAmount[_GrowdropCount]+ToUniswapTokenAmount[_GrowdropCount]), "transfer growdrop error");
        }

        GrowdropStartTime[_GrowdropCount] = now;
        
        GrowdropEndTime[_GrowdropCount] = Add(GrowdropEndTime[_GrowdropCount], now);
        
        EventIdx += 1;
        emit GrowdropAction(EventIdx, _GrowdropCount, address(0x0), 0, 0, 5, now);
    }
    
    /**
     * @dev Investor funds ERC20 token to Growdrop by Growdrop's identifier.
     * Should be approved before call.
     * Funding amount will be calculated as CToken and recalculated to minimum which has same value as calculated CToken before funding.
     * Funding ctoken amount should be bigger than 0.
     * Can be funded only with Growdrop's 'Token'.
     * Can fund only after started and before ended.
     * 
     * Emits {GrowdropAction} event indicating Growdrop's identifier and event information.
     * 
     * @param _GrowdropCount Growdrop's identifier
     * @param Amount ERC20 token amount to fund to Growdrop
     */
    function Mint(uint256 _GrowdropCount, uint256 Amount) public {
        require(GrowdropStart[_GrowdropCount], "not started");
        require(now<GrowdropEndTime[_GrowdropCount], "already ended");
        require(msg.sender!=Beneficiary[_GrowdropCount], "beneficiary cannot mint");
        
        uint256 _exchangeRateCurrent = CToken[_GrowdropCount].exchangeRateCurrent();
        uint256 _ctoken;
        uint256 _toMinAmount;
        (_ctoken, _toMinAmount) = toMinAmount(Amount, _exchangeRateCurrent);
        require(_ctoken>0, "amount too low");
        uint256 actualAmount;
        uint256 actualCToken;
        (actualCToken, actualAmount) = toActualAmount(_toMinAmount, _exchangeRateCurrent);

        CTokenPerAddress[_GrowdropCount][msg.sender] = Add(CTokenPerAddress[_GrowdropCount][msg.sender], _ctoken);
        TotalCTokenAmount[_GrowdropCount] = Add(TotalCTokenAmount[_GrowdropCount], _ctoken);
        
        ActualCTokenPerAddress[_GrowdropCount][msg.sender] = Add(ActualCTokenPerAddress[_GrowdropCount][msg.sender], actualCToken);
        TotalCTokenActual[_GrowdropCount] = Add(TotalCTokenActual[_GrowdropCount], actualCToken);
        

        InvestAmountPerAddress[_GrowdropCount][msg.sender] = Add(InvestAmountPerAddress[_GrowdropCount][msg.sender], _toMinAmount);
        TotalMintedAmount[_GrowdropCount] = Add(TotalMintedAmount[_GrowdropCount], _toMinAmount);
        
        ActualPerAddress[_GrowdropCount][msg.sender] = Add(ActualPerAddress[_GrowdropCount][msg.sender], actualAmount);
        TotalMintedActual[_GrowdropCount] = Add(TotalMintedActual[_GrowdropCount], actualAmount);

        require(Token[_GrowdropCount].transferFrom(msg.sender, address(this), _toMinAmount), "transfer token error");
        require(Token[_GrowdropCount].approve(address(CToken[_GrowdropCount]), _toMinAmount), "approve token error");
        require(CToken[_GrowdropCount].mint(_toMinAmount)==0, "error in mint");
        
        TotalUserInvestedAmount[msg.sender][address(Token[_GrowdropCount])] = Add(TotalUserInvestedAmount[msg.sender][address(Token[_GrowdropCount])],_toMinAmount);
        EventIdx += 1;
        emit GrowdropAction(EventIdx,_GrowdropCount, msg.sender, InvestAmountPerAddress[_GrowdropCount][msg.sender], CTokenPerAddress[_GrowdropCount][msg.sender], 0, now);
    }
    
    /**
     * @dev Investor refunds ERC20 token to Growdrop by Growdrop's identifier.
     * Refunding CToken amount should be bigger than 0.
     * Refunding amount calculated as CToken should be smaller than investor's funded amount calculated as CToken by Growdrop's identifier.
     * Can refund only after started and before ended.
     * 
     * Emits {GrowdropAction} event indicating Growdrop's identifier and event information.
     * 
     * @param _GrowdropCount Growdrop's identifier
     * @param Amount ERC20 token amount to refund to Growdrop
     */
    function Redeem(uint256 _GrowdropCount, uint256 Amount) public {
        require(GrowdropStart[_GrowdropCount], "not started");
        require(now<GrowdropEndTime[_GrowdropCount], "already ended");

        uint256 _exchangeRateCurrent = CToken[_GrowdropCount].exchangeRateCurrent();
        uint256 _ctoken;
        uint256 _toMinAmount;
        (_ctoken,_toMinAmount) = toMinAmount(Amount, _exchangeRateCurrent);
        
        require(_ctoken>0 && _ctoken<=MulAndDiv(InvestAmountPerAddress[_GrowdropCount][msg.sender], 1e18, _exchangeRateCurrent), "redeem error");
        
        uint256 actualAmount;
        uint256 actualCToken;
        (actualCToken, actualAmount) = toActualAmount(_toMinAmount, _exchangeRateCurrent);

        CTokenPerAddress[_GrowdropCount][msg.sender] = Sub(CTokenPerAddress[_GrowdropCount][msg.sender], _ctoken);
        TotalCTokenAmount[_GrowdropCount] = Sub(TotalCTokenAmount[_GrowdropCount],_ctoken);
        
        ActualCTokenPerAddress[_GrowdropCount][msg.sender] = Sub(ActualCTokenPerAddress[_GrowdropCount][msg.sender], actualCToken);
        TotalCTokenActual[_GrowdropCount] = Sub(TotalCTokenActual[_GrowdropCount], actualCToken);
        

        InvestAmountPerAddress[_GrowdropCount][msg.sender] = Sub(InvestAmountPerAddress[_GrowdropCount][msg.sender], _toMinAmount);
        TotalMintedAmount[_GrowdropCount] = Sub(TotalMintedAmount[_GrowdropCount], _toMinAmount);
        
        ActualPerAddress[_GrowdropCount][msg.sender] = Sub(ActualPerAddress[_GrowdropCount][msg.sender], actualAmount);
        TotalMintedActual[_GrowdropCount] = Sub(TotalMintedActual[_GrowdropCount], actualAmount);

        require(CToken[_GrowdropCount].redeemUnderlying(Amount)==0, "error in redeem");
        require(Token[_GrowdropCount].transfer(msg.sender, Amount), "transfer token error");

        TotalUserInvestedAmount[msg.sender][address(Token[_GrowdropCount])] = Sub(TotalUserInvestedAmount[msg.sender][address(Token[_GrowdropCount])], _toMinAmount);

        EventIdx += 1;
        emit GrowdropAction(EventIdx, _GrowdropCount, msg.sender, InvestAmountPerAddress[_GrowdropCount][msg.sender], CTokenPerAddress[_GrowdropCount][msg.sender], 1, now);
    }
    
    /**
     * @dev Investor and Investee withdraws from Growdrop by Growdrop's identifier.
     * Investor withdraws investor's all funded ERC20 token amount and 'GrowdropToken' calculated by percentage of investor's accrued interest amount.
     * If Growdrop is donation, Investor withdraws investor's all funded ERC20 token amount and ERC721 token from 'DonateToken'.
     * Investee withdraws all investor's accrued interest if 'ToUniswap' is false.
     * Else add liquidity to Uniswap with 'ToUniswapInterestRate' percentage of all investor's accrued interest amount and 'ToUniswapTokenAmount' ERC20 token
     * and withdraw rest of all investor's accured interest amount.
     * If Growdrop is donation, Investee withdraws investor's all funded ERC20 token amount.
     * Owner fee is transferred when Investee withdraws.
     * Can withdraw only once per address.
     * Can withdraw only after ended.
     * 
     * Emits {GrowdropAction} event indicating Growdrop's identifier and event information.
     * Emits {DonateAction} event indicating ERC721 token information from 'DonateToken' if Growdrop is donation.
     * 
     * @param _GrowdropCount Growdrop's identifier
     * @param ToUniswap if investee wants to add liquidity to UniswapExchange, true. Else false.
     */
    function Withdraw(uint256 _GrowdropCount, bool ToUniswap) public {
        require(!WithdrawOver[_GrowdropCount][msg.sender], "already done");
        
        WithdrawOver[_GrowdropCount][msg.sender] = true;
        
        EndGrowdrop(_GrowdropCount);
        //If investee did not want to add to UniswapExchange, does not add to UniswapExchange.
        if(!AddToUniswap[_GrowdropCount]) {
            ToUniswap = false;
        }
        //If caller is investee
        if(msg.sender==Beneficiary[_GrowdropCount]) {
            uint256 beneficiaryinterest;
            bool success;
            if(TotalInterestOverActual[_GrowdropCount]==0) {
                ToUniswap=false;
                success=true;
            }
            uint256 OwnerFee = MulAndDiv(TotalInterestOver[_GrowdropCount], GrowdropOwnerFeePercent[_GrowdropCount], 100);
            if(ToUniswap) {
                uint256 ToUniswapInterestRateCalculated = MulAndDiv(TotalInterestOver[_GrowdropCount], ToUniswapInterestRate[_GrowdropCount], 100);
                beneficiaryinterest = TotalInterestOver[_GrowdropCount]-ToUniswapInterestRateCalculated-OwnerFee;
                
                require(Token[_GrowdropCount].approve(address(Tokenswap), ToUniswapInterestRateCalculated), "approve token error");
                require(GrowdropToken[_GrowdropCount].approve(address(Tokenswap), ToUniswapTokenAmount[_GrowdropCount]), "approve growdrop error");
                success = Tokenswap.addPoolToUniswap(
                    address(Token[_GrowdropCount]),
                    address(GrowdropToken[_GrowdropCount]),
                    Beneficiary[_GrowdropCount],
                    ToUniswapInterestRateCalculated,
                    ToUniswapTokenAmount[_GrowdropCount]
                );
                
                if(!success) {
                    beneficiaryinterest += ToUniswapInterestRateCalculated;
                }
                
            } else {
                beneficiaryinterest = TotalInterestOver[_GrowdropCount]-OwnerFee;
                if(DonateId[_GrowdropCount]!=0) {
                    success=true;
                }
            }
            sendTokenInWithdraw(_GrowdropCount, Beneficiary[_GrowdropCount], beneficiaryinterest, success ? 0 : ToUniswapTokenAmount[_GrowdropCount]);
            require(Token[_GrowdropCount].transfer(owner, OwnerFee), "transfer fee error");
            
            EventIdx += 1;
            emit GrowdropAction(EventIdx, _GrowdropCount, msg.sender, beneficiaryinterest, success ? 1 : 0, 2, now);
        } else {
            //If caller is investor
            uint256 investorTotalInterest = MulAndDiv(ActualCTokenPerAddress[_GrowdropCount][msg.sender], ExchangeRateOver[_GrowdropCount], 1) - ActualPerAddress[_GrowdropCount][msg.sender];
            
            uint256 tokenByInterest = DonateId[_GrowdropCount]==0 ? MulAndDiv(
                investorTotalInterest,
                GrowdropAmount[_GrowdropCount],
                (TotalInterestOverActual[_GrowdropCount]==0 ? 1 : TotalInterestOverActual[_GrowdropCount])
            ) : investorTotalInterest;
            tokenByInterest = sendTokenInWithdraw(_GrowdropCount, msg.sender, InvestAmountPerAddress[_GrowdropCount][msg.sender], tokenByInterest);

            TotalUserInvestedAmount[msg.sender][address(Token[_GrowdropCount])] = Sub(TotalUserInvestedAmount[msg.sender][address(Token[_GrowdropCount])], InvestAmountPerAddress[_GrowdropCount][msg.sender]);
            EventIdx += 1;
            emit GrowdropAction(EventIdx, _GrowdropCount, msg.sender, InvestAmountPerAddress[_GrowdropCount][msg.sender], tokenByInterest, 3, now);
        }
    }
    
    /**
     * @dev Transfers ERC20 tokens to 'To' address.
     * If Growdrop by '_GrowdropCount' is donation, 'DonateToken' mints new ERC721 token.
     * 
     * Emits {DonateAction} event indicating ERC721 token information from 'DonateToken' if Growdrop is donation.
     * 
     * @param _GrowdropCount Growdrop's identifier
     * @param To address to send ERC20 tokens
     * @param TokenAmount ERC20 token amount of 'Token'
     * @param GrowdropTokenAmount ERC20 token amount of 'GrowdropToken'
     * @return if Growdrop by '_GrowdropCount' is donation, return new ERC721 token's identifier. Else return ERC20 token amount of 'GrowdropToken'
     */
    function sendTokenInWithdraw(uint256 _GrowdropCount, address To, uint256 TokenAmount, uint256 GrowdropTokenAmount) private returns (uint256) {
        require(Token[_GrowdropCount].transfer(To, TokenAmount), "transfer token error");
        if(DonateId[_GrowdropCount]==0) {
            require(GrowdropToken[_GrowdropCount].transfer(To, GrowdropTokenAmount), "transfer growdrop error");
            return GrowdropTokenAmount;
        } else {
            return DonateToken.mint(msg.sender, Beneficiary[_GrowdropCount], address(Token[_GrowdropCount]), GrowdropTokenAmount, DonateId[_GrowdropCount]);
        }
    }
    
    /**
     * @dev Ends Growdrop by '_GrowdropCount'.
     * If total actual accrued interest is 0 and Growdrop is not donation, transfers 'GrowdropAmount' and 'ToUniswapTokenAmount' back to 'Beneficiary'.
     * Total accrued interest is calculated -> maximum amount of Growdrop's all CToken to ERC20 token - total funded ERC20 amount of Growdrop.
     * 
     * Emits {GrowdropAction} event indicating Growdrop's identifier and event information.
     * 
     * @param _GrowdropCount Growdrop's identifier
     */
    function EndGrowdrop(uint256 _GrowdropCount) private {
        require(GrowdropStart[_GrowdropCount] && GrowdropEndTime[_GrowdropCount]<=now, "cannot end now");
        if(!GrowdropOver[_GrowdropCount]) {
            GrowdropOver[_GrowdropCount] = true;
            
            ExchangeRateOver[_GrowdropCount] = CToken[_GrowdropCount].exchangeRateCurrent();
            uint256 _toAmount = TotalCTokenAmount[_GrowdropCount]>0 ? MulAndDiv(TotalCTokenAmount[_GrowdropCount]+1, ExchangeRateOver[_GrowdropCount], 1e18) : 0;

            if(TotalCTokenAmount[_GrowdropCount]!=0) {
                require(CToken[_GrowdropCount].redeemUnderlying(_toAmount)==0, "error in redeem");
            }
            TotalInterestOverActual[_GrowdropCount] = MulAndDiv(TotalCTokenActual[_GrowdropCount], ExchangeRateOver[_GrowdropCount], 1) - TotalMintedActual[_GrowdropCount];
            
            TotalInterestOver[_GrowdropCount] = _toAmount>TotalMintedAmount[_GrowdropCount] ? _toAmount-TotalMintedAmount[_GrowdropCount] : 0;
            if(TotalInterestOverActual[_GrowdropCount]==0) {
                if(DonateId[_GrowdropCount]==0) {
                    require(
                        GrowdropToken[_GrowdropCount].transfer(
                            Beneficiary[_GrowdropCount],
                            GrowdropAmount[_GrowdropCount]+ToUniswapTokenAmount[_GrowdropCount]
                        )
                    );
                }
            }
            
            EventIdx += 1;
            emit GrowdropAction(EventIdx, _GrowdropCount, msg.sender, TotalInterestOverActual[_GrowdropCount]==0 ? 1 : 0, 0, 6, now);
        }
    }
    
    /**
     * @dev Calculates CToken and maximum amount of ERC20 token from ERC20 token amount and exchange rate of Compound CToken.
     * @param tokenAmount ERC20 token amount
     * @param exchangeRate exchange rate of Compound CToken
     * @return calculated CToken amount
     * @return calculated maximum amount of ERC20 token
     */
    function toMaxAmount(uint256 tokenAmount, uint256 exchangeRate) private pure returns (uint256, uint256) {
        uint256 _ctoken = MulAndDiv(tokenAmount, 1e18, exchangeRate);
        return (_ctoken, MulAndDiv(
            Add(_ctoken, 1),
            exchangeRate,
            1e18
        ));
    }
    
    /**
     * @dev Calculates CToken and minimum amount of ERC20 token from ERC20 token amount and exchange rate of Compound CToken.
     * @param tokenAmount ERC20 token amount
     * @param exchangeRate exchange rate of Compound CToken
     * @return calculated CToken amount
     * @return calculated minimum amount of ERC20 token
     */
    function toMinAmount(uint256 tokenAmount, uint256 exchangeRate) private pure returns (uint256, uint256) {
        uint256 _ctoken = MulAndDiv(tokenAmount, 1e18, exchangeRate);
        return (_ctoken, Add(
            MulAndDiv(
                _ctoken,
                exchangeRate,
                1e18
            ),
            1
        ));
    }
    
    /**
     * @dev Calculates actual CToken and amount of ERC20 token from ERC20 token amount and exchange rate of Compound CToken.
     * Need for calculating percentage of interest accrued.
     * @param tokenAmount ERC20 token amount
     * @param exchangeRate exchange rate of Compound CToken
     * @return calculated actual CToken amount
     * @return calculated actual minimum amount of ERC20 token
     */
    function toActualAmount(uint256 tokenAmount, uint256 exchangeRate) private pure returns (uint256, uint256) {
        uint256 _ctoken = MulAndDiv(tokenAmount, 1e29, exchangeRate);
        uint256 _token = MulAndDiv(_ctoken, exchangeRate, 1);
        return (_ctoken, _token);
    }
    
    function MulAndDiv(uint256 a, uint256 b, uint256 c) private pure returns (uint256) {
        uint256 temp = a*b;
        require(temp/b==a && c>0, "arithmetic error");
        return temp/c;
    }
    
    function Add(uint256 a, uint256 b) private pure returns (uint256) {
        require(a+b>=a, "add overflow");
        return a+b;
    }
    
    function Sub(uint256 a, uint256 b) private pure returns (uint256) {
        require(a>=b, "subtract overflow");
        return a-b;
    }
    
    /**
     * @dev Emits {DonateAction} event from 'DonateToken' contract.
     * Only 'DonateToken' contract can call.
     * 
     * Emits {DonateAction} event indicating ERC721 token information from 'DonateToken'.
     * 
     * @param From 'DonateToken' ERC721 token's previous owner
     * @param To 'DonateToken' ERC721 token's next owner
     * @param Supporter 'DonateToken' ERC721 token's 'supporter'
     * @param beneficiary 'DonateToken' ERC721 token's 'beneficiary'
     * @param token 'DonateToken' ERC721 token's 'tokenAddress'
     * @param donateId 'DonateToken' ERC721 token's 'donateId'
     * @param tokenId 'DonateToken' ERC721 token's identifier
     * @param Amount 'DonateToken' ERC721 token's 'tokenAmount'
     * @param ActionIdx DonateAction event identifier
     * @return EventIdx event sequential identifier
     */
    function emitDonateActionEvent(
        address From,
        address To,
        address Supporter,
        address beneficiary,
        address token,
        uint256 donateId,
        uint256 tokenId,
        uint256 Amount,
        uint256 ActionIdx) public returns (uint256) {
        require(msg.sender==address(DonateToken), "not donatetoken contract");
        EventIdx += 1;
        emit DonateAction(EventIdx, From, To, Supporter, beneficiary, token, donateId, tokenId, Amount, ActionIdx, now);
        return EventIdx;
    }
    
    /**
     * @dev Set 'DonateToken' contract address.
     * @param DonateTokenAddress 'DonateToken' contract address
     */
    function setDonateToken(address DonateTokenAddress) public {
        require(CheckOwner[msg.sender]);
        DonateToken = DonateTokenInterface(DonateTokenAddress);
    }
    
    /**
     * @dev Set 'Tokenswap' contract address.
     * @param TokenswapAddress 'Tokenswap' contract address
     */
    function setTokenswap(address TokenswapAddress) public {
        require(CheckOwner[msg.sender]);
        Tokenswap = TokenswapInterface(TokenswapAddress);
    }
    
    /**
     * @dev Change 'CheckOwner' state of address .
     * @param _Owner address to change state
     */
    function addOwner(address _Owner) public {
        require(CheckOwner[msg.sender]);
        CheckOwner[_Owner] = !CheckOwner[_Owner];
    }
    
    /**
     * @dev Set 'owner' address .
     * @param _Owner address to set
     */
    function setOwner(address _Owner) public {
        require(CheckOwner[msg.sender] && CheckOwner[_Owner], "not proper owner");
        owner=_Owner;
    }
    
    /**
     * @dev Set 'CurrentOwnerFeePercent'.
     * @param _OwnerFeePercent value to set
     */
    function setOwnerFeePercent(uint256 _OwnerFeePercent) public {
        require(CheckOwner[msg.sender], "not owner");
        require(_OwnerFeePercent>0 && _OwnerFeePercent<100, "not proper percent");
        CurrentOwnerFeePercent=_OwnerFeePercent;
    }

    function () external payable {
        
    }
}
