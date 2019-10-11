pragma solidity ^0.5.11;

import "./Growdrop.sol";

contract GrowdropManager {
    address public Owner;
    mapping(address => bool) public CheckOwner;
    
    address[] public GrowdropList;

    uint256 public EventIdx;

    mapping(address => uint256) public TotalUserInvestedAmount;
    mapping(address => uint256) public TotalUserCount;
    mapping(address => bool) public CheckGrowdropContract;
    mapping(address => mapping(address => bool)) public CheckUserJoinedGrowdrop;
    
    event NewGrowdropContract(uint256 indexed _eventIdx, uint256 indexed _idx, address indexed _beneficiary, address _GrowdropAddress);

    event GrowdropAction(uint256 indexed _eventIdx, address indexed _Growdrop, bool indexed _ActionIdx, uint256 _ActionTime);
    
    event UserAction(uint256 indexed _eventIdx, address indexed _Growdrop, address indexed _From, uint256 _Amount, uint256 _ActionTime, uint256 _ActionIdx);
    
    constructor () public {
        Owner=msg.sender;
        CheckOwner[msg.sender]=true;
    }
    
    function newGrowdrop(address TokenAddr, address CTokenAddr, address GrowdropTokenAddr, address BeneficiaryAddr, uint256 GrowdropAmount, uint256 GrowdropPeriod, uint256 ToUniswapTokenAmount, uint256 ToUniswapInterestRate, address KyberTokenAddr) public {
        require(CheckOwner[msg.sender]);
        Growdrop newGrowdropContract = new Growdrop(TokenAddr, CTokenAddr, GrowdropTokenAddr, BeneficiaryAddr, GrowdropAmount, GrowdropPeriod, ToUniswapTokenAmount, ToUniswapInterestRate, KyberTokenAddr);
        CheckGrowdropContract[address(newGrowdropContract)]=true;
        uint256 idx = GrowdropList.push(address(newGrowdropContract))-1;
        EventIdx++;
        emit NewGrowdropContract(EventIdx, idx, BeneficiaryAddr, address(newGrowdropContract));
    }
    
    function emitGrowdropActionEvent(bool ActionIdx, uint256 ActionTime) public returns (bool) {
        require(CheckGrowdropContract[msg.sender]);
        EventIdx++;
        emit GrowdropAction(EventIdx, msg.sender, ActionIdx, ActionTime);
        return true;
    }
    
    function emitUserActionEvent(address From, uint256 Amount, uint256 ActionTime, uint256 ActionIdx, uint256 AddOrSubValue) public returns (bool) {
        require(CheckGrowdropContract[msg.sender]);
        EventIdx++;
        if(ActionIdx==0) {
            require(TotalUserInvestedAmount[From]+AddOrSubValue>=TotalUserInvestedAmount[From]);
            TotalUserInvestedAmount[From]+=AddOrSubValue;
        } else if (ActionIdx==1 || ActionIdx==3) {
            require(TotalUserInvestedAmount[From]>=AddOrSubValue);
            TotalUserInvestedAmount[From]-=AddOrSubValue;
        } else if(ActionIdx==4) {
            CheckUserJoinedGrowdrop[msg.sender][From]=true;
            TotalUserCount[msg.sender]++;
        }
        emit UserAction(EventIdx, msg.sender, From, Amount, ActionTime, ActionIdx);
        return true;
    }

    function addOwner(address _Owner) public {
        require(CheckOwner[msg.sender]);
        CheckOwner[_Owner]=!CheckOwner[_Owner];
    }
    
    function getGrowdropListLength() public view returns (uint256) {
        return GrowdropList.length;
    }
}
