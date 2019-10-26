pragma solidity ^0.5.11;

import "./Growdrop.sol";
import "./DonateTokenInterface.sol";
import "./TokenswapInterface.sol";

contract GrowdropManager {
    address public Owner;
    mapping(address => bool) public CheckOwner;
    DonateTokenInterface public DonateToken;
    TokenswapInterface public Tokenswap;
    
    address[] public GrowdropList;

    uint256 public EventIdx;

    mapping(address => uint256) public TotalUserInvestedAmount;
    mapping(address => uint256) public TotalUserCount;
    mapping(address => bool) public CheckGrowdropContract;
    mapping(address => mapping(address => bool)) public CheckUserJoinedGrowdrop;
    
    event NewGrowdropContract(uint256 indexed _eventIdx, uint256 indexed _idx, address indexed _beneficiary, address _GrowdropAddress);
    
    event GrowdropAction(uint256 indexed _eventIdx, address indexed _Growdrop, address indexed _From, uint256 _Amount, uint256 _ActionTime, uint256 _ActionIdx);
    
    constructor () public {
        Owner=msg.sender;
        CheckOwner[msg.sender]=true;
    }
    
    function newGrowdrop(address TokenAddr, address CTokenAddr, address GrowdropTokenAddr, address BeneficiaryAddr, uint256 GrowdropAmount, uint256 GrowdropPeriod, uint256 ToUniswapTokenAmount, uint256 ToUniswapInterestRate, uint256 DonateId) public {
        require(CheckOwner[msg.sender]);
        require(DonateToken.DonateIdOwner(DonateId)==BeneficiaryAddr || DonateId==0);
        address newGrowdropContract = address(new Growdrop(TokenAddr, CTokenAddr, GrowdropTokenAddr, BeneficiaryAddr, GrowdropAmount, GrowdropPeriod, ToUniswapTokenAmount, ToUniswapInterestRate, DonateId));
        CheckGrowdropContract[newGrowdropContract]=true;
        uint256 idx = GrowdropList.push(newGrowdropContract)-1;
        EventIdx+=1;
        emit NewGrowdropContract(EventIdx, idx, BeneficiaryAddr, newGrowdropContract);
    }
    
    function emitGrowdropActionEvent(address From, uint256 Amount, uint256 ActionTime, uint256 ActionIdx, uint256 AddOrSubValue) public returns (bool) {
        require(CheckGrowdropContract[msg.sender]);
        EventIdx+=1;
        if(ActionIdx==0) {
            TotalUserInvestedAmount[From]+=AddOrSubValue;
            require(TotalUserInvestedAmount[From]>=AddOrSubValue);
        } else if (ActionIdx==1 || ActionIdx==3) {
            require(TotalUserInvestedAmount[From]>=AddOrSubValue);
            TotalUserInvestedAmount[From]-=AddOrSubValue;
        } else if(ActionIdx==4) {
            CheckUserJoinedGrowdrop[msg.sender][From]=true;
            TotalUserCount[msg.sender]+=1;
        } 
        emit GrowdropAction(EventIdx, msg.sender, From, Amount, ActionTime, ActionIdx);
        return true;
    }
    
    function setDonateToken(address DonateTokenAddress) public {
        require(CheckOwner[msg.sender]);
        DonateToken=DonateTokenInterface(DonateTokenAddress);
    }

    function setTokenswap(address TokenswapAddress) public {
        require(CheckOwner[msg.sender]);
        Tokenswap=TokenswapInterface(TokenswapAddress);
    }

    function addOwner(address _Owner) public {
        require(CheckOwner[msg.sender]);
        CheckOwner[_Owner]=!CheckOwner[_Owner];
    }
    
    function getGrowdropListLength() public view returns (uint256) {
        return GrowdropList.length;
    }
}