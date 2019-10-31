pragma solidity ^0.5.11;

import "./DonateTokenInterface.sol";
import "./EIP20Interface.sol";
import "./CTokenInterface.sol";
import "./UniswapFactoryInterface.sol";
import "./KyberNetworkProxyInterface.sol";
import "./TokenswapInterface.sol";

contract Growdrop {
    address public owner;
    mapping(address => bool) public CheckOwner;
    DonateTokenInterface public DonateToken;
    TokenswapInterface public Tokenswap;
    
    uint256 public GrowdropCount;
    uint256 public EventIdx;

    mapping(uint256 => address) public Beneficiary;
    mapping(uint256 => mapping(address => uint256)) public CTokenPerAddress;
    mapping(uint256 => mapping(address => uint256)) public InvestAmountPerAddress;
    mapping(uint256 => mapping(address => bool)) public WithdrawOver;
    mapping(uint256 => uint256) public GrowdropAmount;
    mapping(uint256 => uint256) public GrowdropStartTime;
    mapping(uint256 => uint256) public GrowdropEndTime;
    mapping(uint256 => uint256) public TotalMintedAmount;
    mapping(uint256 => uint256) public TotalCTokenAmount;
    mapping(uint256 => uint256) public ExchangeRateOver;
    mapping(uint256 => uint256) public TotalInterestOver;
    mapping(uint256 => uint256) public ToUniswapTokenAmount;
    mapping(uint256 => uint256) public ToUniswapInterestRate;
    mapping(uint256 => bool) public GrowdropOver;
    mapping(uint256 => bool) public GrowdropStart;
    mapping(uint256 => uint256) public DonateId;
    mapping(uint256 => EIP20Interface) public Token;
    mapping(uint256 => EIP20Interface) public GrowdropToken;
    mapping(uint256 => CTokenInterface) public CToken;
    
    mapping(uint256 => EIP20Interface) public KyberToken;
    uint256 constant Minimum=10**14;
    uint256 constant ConstVal=10**18;
    uint256 public AllCTokenAmount;
    uint256 public AllInvestAmount;


    mapping(address => uint256) public TotalUserInvestedAmount;
    mapping(uint256 => uint256) public TotalUserCount;
    mapping(uint256 => mapping(address => bool)) public CheckUserJoinedGrowdrop;
    
    event NewGrowdropContract(
        uint256 indexed _EventIdx,
        uint256 indexed _Idx,
        address indexed _Beneficiary
    );
    
    event GrowdropAction(
        uint256 indexed _EventIdx,
        address indexed _From,
        uint256 _Amount1,
        uint256 _Amount2,
        uint256 _ActionIdx
    );

    event DonateAction(
        uint256 indexed _EventIdx,
        address indexed _From,
        address indexed _To,
        address _Supporter,
        address _Beneficiary,
        address _Token,
        uint256 _DonateId,
        uint256 _Amount,
        uint256 _ActionIdx
    );

    constructor () public {
        owner = msg.sender;
        CheckOwner[msg.sender] = true;
    }

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
        GrowdropCount += 1;

        Token[GrowdropCount] = EIP20Interface(TokenAddr);
        CToken[GrowdropCount] = CTokenInterface(CTokenAddr);
        GrowdropToken[GrowdropCount] = EIP20Interface(GrowdropTokenAddr);
        Beneficiary[GrowdropCount] = BeneficiaryAddr;
        GrowdropAmount[GrowdropCount] = _GrowdropAmount;
        
        require(GrowdropPeriod>0);
        GrowdropEndTime[GrowdropCount] = GrowdropPeriod;
        
        require(_ToUniswapInterestRate>0 && _ToUniswapInterestRate<98);
        require(_ToUniswapTokenAmount>Minimum && _GrowdropAmount>Minimum);
        require(_GrowdropAmount+_ToUniswapTokenAmount>_ToUniswapTokenAmount);
        ToUniswapTokenAmount[GrowdropCount] = _ToUniswapTokenAmount;
        ToUniswapInterestRate[GrowdropCount] = _ToUniswapInterestRate;
        
        DonateId[GrowdropCount] = _DonateId;
        
        //kovan address
        KyberToken[GrowdropCount] = EIP20Interface(0xC4375B7De8af5a38a93548eb8453a498222C4fF2);

        EventIdx += 1;
        emit NewGrowdropContract(EventIdx, GrowdropCount, BeneficiaryAddr);
    }
    
    function StartGrowdrop(uint256 _GrowdropCount) public {
        require(msg.sender==Beneficiary[_GrowdropCount]);
        require(!GrowdropStart[_GrowdropCount]);
        GrowdropStart[_GrowdropCount] = true;
        
        if(DonateId[_GrowdropCount]==0) {
            require(GrowdropToken[_GrowdropCount].transferFrom(msg.sender, address(this), GrowdropAmount[_GrowdropCount]+ToUniswapTokenAmount[_GrowdropCount]));
        }

        GrowdropStartTime[_GrowdropCount] = now;
        
        GrowdropEndTime[_GrowdropCount] = Add(GrowdropEndTime[_GrowdropCount], now);
        
        EventIdx += 1;
        emit GrowdropAction(EventIdx, address(0x0), 0, 0, 5);
    }
    
    function Mint(uint256 _GrowdropCount, uint256 Amount) public {
        require(GrowdropStart[_GrowdropCount]);
        require(now<GrowdropEndTime[_GrowdropCount]);
        require(msg.sender!=Beneficiary[_GrowdropCount]);
        require(Amount>Minimum);
        
        uint256 _exchangeRateCurrent = CToken[_GrowdropCount].exchangeRateCurrent();
        uint256 _ctoken;
        uint256 _toMinAmount;
        (_ctoken, _toMinAmount) = toMinAmount(Amount, _exchangeRateCurrent);

        CTokenPerAddress[_GrowdropCount][msg.sender] = Add(CTokenPerAddress[_GrowdropCount][msg.sender], _ctoken);
        TotalCTokenAmount[_GrowdropCount] = Add(TotalCTokenAmount[_GrowdropCount], _ctoken);
        AllCTokenAmount = Add(AllCTokenAmount, _ctoken);

        InvestAmountPerAddress[_GrowdropCount][msg.sender] = Add(InvestAmountPerAddress[_GrowdropCount][msg.sender], _toMinAmount);
        TotalMintedAmount[_GrowdropCount] = Add(TotalMintedAmount[_GrowdropCount], _toMinAmount);
        AllInvestAmount = Add(AllInvestAmount, _toMinAmount);

        require(Token[_GrowdropCount].transferFrom(msg.sender, address(this), _toMinAmount));
        require(Token[_GrowdropCount].approve(address(CToken[_GrowdropCount]), _toMinAmount));
        require(CToken[_GrowdropCount].mint(_toMinAmount)==0);
        
        if(!CheckUserJoinedGrowdrop[_GrowdropCount][msg.sender]) {
            CheckUserJoinedGrowdrop[_GrowdropCount][msg.sender] = true;
            TotalUserCount[_GrowdropCount] += 1;
        }
        TotalUserInvestedAmount[msg.sender] = Add(TotalUserInvestedAmount[msg.sender],_toMinAmount);
        EventIdx += 1;
        emit GrowdropAction(EventIdx, msg.sender, InvestAmountPerAddress[_GrowdropCount][msg.sender], CTokenPerAddress[_GrowdropCount][msg.sender], 0);
    }
    
    function Redeem(uint256 _GrowdropCount, uint256 Amount) public {
        require(GrowdropStart[_GrowdropCount]);
        require(now<GrowdropEndTime[_GrowdropCount]);
        require(msg.sender!=Beneficiary[_GrowdropCount]);
        require(Amount>Minimum || Amount==0);
        
        if(Amount==0) {
            Amount = InvestAmountPerAddress[_GrowdropCount][msg.sender];
        }

        uint256 _exchangeRateCurrent = CToken[_GrowdropCount].exchangeRateCurrent();
        uint256 _ctoken;
        uint256 _toMaxAmount;
        (_ctoken, _toMaxAmount) = toMaxAmount(Amount, _exchangeRateCurrent);
        require(_ctoken<=MulAndDiv(InvestAmountPerAddress[_GrowdropCount][msg.sender], ConstVal, _exchangeRateCurrent));

        CTokenPerAddress[_GrowdropCount][msg.sender] = Sub(CTokenPerAddress[_GrowdropCount][msg.sender], _ctoken);
        TotalCTokenAmount[_GrowdropCount] = Sub(TotalCTokenAmount[_GrowdropCount],_ctoken);
        AllCTokenAmount = Sub(AllCTokenAmount, _ctoken);

        uint256 _toMinAmount;
        (,_toMinAmount) = toMinAmount(Amount, _exchangeRateCurrent);

        InvestAmountPerAddress[_GrowdropCount][msg.sender] = Sub(InvestAmountPerAddress[_GrowdropCount][msg.sender], _toMinAmount);
        TotalMintedAmount[_GrowdropCount] = Sub(TotalMintedAmount[_GrowdropCount], _toMinAmount);
        AllInvestAmount = Sub(AllInvestAmount, _toMinAmount);

        require(CToken[_GrowdropCount].redeemUnderlying(_toMaxAmount)==0);
        require(Token[_GrowdropCount].transfer(msg.sender, _toMaxAmount));

        TotalUserInvestedAmount[msg.sender] = Sub(TotalUserInvestedAmount[msg.sender], _toMinAmount);

        EventIdx += 1;
        emit GrowdropAction(EventIdx, msg.sender, InvestAmountPerAddress[_GrowdropCount][msg.sender], CTokenPerAddress[_GrowdropCount][msg.sender], 1);
    }
    
    function Withdraw(uint256 _GrowdropCount, bool ToUniswap) public {
        require(!WithdrawOver[_GrowdropCount][msg.sender]);
        
        WithdrawOver[_GrowdropCount][msg.sender] = true;
        
        EndGrowdrop(_GrowdropCount);
        if(TotalCTokenAmount[_GrowdropCount]==0) {
            return;
        }
        if(DonateId[_GrowdropCount]!=0) {
            ToUniswap = false;
        }
        if(msg.sender==Beneficiary[_GrowdropCount]) {
            uint256 OwnerFee = MulAndDiv(TotalInterestOver[_GrowdropCount], 3, 100);
            uint256 swappedTokenAmount;
            uint256 beneficiaryinterest;
            if(ToUniswap) {
                uint256 ToUniswapInterestRateCalculated = MulAndDiv(TotalInterestOver[_GrowdropCount], ToUniswapInterestRate[_GrowdropCount], 100);
                beneficiaryinterest = Sub(Sub(TotalInterestOver[_GrowdropCount],ToUniswapInterestRateCalculated),OwnerFee);
                require(Token[_GrowdropCount].transfer(Beneficiary[_GrowdropCount], beneficiaryinterest));
                
                require(Token[_GrowdropCount].approve(address(Tokenswap), ToUniswapInterestRateCalculated));
                swappedTokenAmount = Tokenswap.uniswapToken(address(Token[_GrowdropCount]),address(KyberToken[_GrowdropCount]),ToUniswapInterestRateCalculated);
                
                require(KyberToken[_GrowdropCount].approve(address(Tokenswap), swappedTokenAmount));
                require(GrowdropToken[_GrowdropCount].approve(address(Tokenswap), ToUniswapTokenAmount[_GrowdropCount]));
                bool success = Tokenswap.addPoolToUniswap(
                    address(KyberToken[_GrowdropCount]),
                    address(GrowdropToken[_GrowdropCount]),
                    Beneficiary[_GrowdropCount],
                    swappedTokenAmount,
                    ToUniswapTokenAmount[_GrowdropCount]
                );
                if(success) {
                    swappedTokenAmount = 0;
                }
            } else {
                beneficiaryinterest = Sub(TotalInterestOver[_GrowdropCount], OwnerFee);
                if(DonateId[_GrowdropCount]==0) {
                    sendTokenInWithdraw(_GrowdropCount, Beneficiary[_GrowdropCount], beneficiaryinterest, ToUniswapTokenAmount[_GrowdropCount]);
                } else {
                    Token[_GrowdropCount].transfer(Beneficiary[_GrowdropCount], beneficiaryinterest);
                }
            }
            require(Token[_GrowdropCount].transfer(owner, OwnerFee));
            
            EventIdx += 1;
            emit GrowdropAction(EventIdx, msg.sender, beneficiaryinterest, swappedTokenAmount, 2);
        } else {
            uint256 investorTotalAmount = MulAndDiv(CTokenPerAddress[_GrowdropCount][msg.sender], ExchangeRateOver[_GrowdropCount], ConstVal);
            uint256 investorTotalInterest = Sub(investorTotalAmount, InvestAmountPerAddress[_GrowdropCount][msg.sender]);
            uint256 tokenByInterest = MulAndDiv(
                GrowdropAmount[_GrowdropCount],
                investorTotalInterest,
                TotalInterestOver[_GrowdropCount]
            );
            if(DonateId[_GrowdropCount]!=0) tokenByInterest = investorTotalInterest;
            tokenByInterest = sendTokenInWithdraw(_GrowdropCount, msg.sender, InvestAmountPerAddress[_GrowdropCount][msg.sender], tokenByInterest);

            TotalUserInvestedAmount[msg.sender] = Sub(TotalUserInvestedAmount[msg.sender], InvestAmountPerAddress[_GrowdropCount][msg.sender]);
            EventIdx += 1;
            emit GrowdropAction(EventIdx, msg.sender, InvestAmountPerAddress[_GrowdropCount][msg.sender], tokenByInterest, 3);
        }
    }
    
    function sendTokenInWithdraw(uint256 _GrowdropCount, address To, uint256 TokenAmount, uint256 GrowdropTokenAmount) private returns (uint256) {
        require(Token[_GrowdropCount].transfer(To, TokenAmount));
        if(DonateId[_GrowdropCount]==0) {
            require(GrowdropToken[_GrowdropCount].transfer(To, GrowdropTokenAmount));
            return GrowdropTokenAmount;
        } else {
            return DonateToken.mint(msg.sender, Beneficiary[_GrowdropCount], address(Token[_GrowdropCount]), GrowdropTokenAmount, DonateId[_GrowdropCount]);
        }
    }
    
    function EndGrowdrop(uint256 _GrowdropCount) private {
        require(GrowdropStart[_GrowdropCount] && GrowdropEndTime[_GrowdropCount]<=now);
        if(!GrowdropOver[_GrowdropCount]) {
            GrowdropOver[_GrowdropCount] = true;
            
            ExchangeRateOver[_GrowdropCount] = CToken[_GrowdropCount].exchangeRateCurrent();
            uint256 _toAmount = MulAndDiv(Add(TotalCTokenAmount[_GrowdropCount],1), ExchangeRateOver[_GrowdropCount], ConstVal);

            if(TotalCTokenAmount[_GrowdropCount]==0) {
                if(DonateId[_GrowdropCount]==0) {
                    require(
                        GrowdropToken[_GrowdropCount].transfer(
                            Beneficiary[_GrowdropCount],
                            Add(GrowdropAmount[_GrowdropCount],ToUniswapTokenAmount[_GrowdropCount])
                        )
                    );
                }
            } else {
                require(CToken[_GrowdropCount].redeemUnderlying(_toAmount)==0);
            }
            TotalInterestOver[_GrowdropCount] = Sub(_toAmount, TotalMintedAmount[_GrowdropCount]);
            
            EventIdx += 1;
            emit GrowdropAction(EventIdx, msg.sender, 0, 0, 6);
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

    function emitDonateActionEvent(
        address From,
        address To,
        address Supporter,
        address beneficiary,
        address token,
        uint256 donateId,
        uint256 Amount,
        uint256 ActionIdx) public returns (uint256) {
        require(msg.sender==address(DonateToken));
        EventIdx += 1;
        emit DonateAction(EventIdx, From, To, Supporter, beneficiary, token, donateId, Amount, ActionIdx);
        return EventIdx;
    }
    
    function setDonateToken(address DonateTokenAddress) public {
        require(CheckOwner[msg.sender]);
        DonateToken = DonateTokenInterface(DonateTokenAddress);
    }

    function setTokenswap(address TokenswapAddress) public {
        require(CheckOwner[msg.sender]);
        Tokenswap = TokenswapInterface(TokenswapAddress);
    }

    function addOwner(address _Owner) public {
        require(CheckOwner[msg.sender]);
        CheckOwner[_Owner] = !CheckOwner[_Owner];
    }

    function () external payable {
        
    }
}