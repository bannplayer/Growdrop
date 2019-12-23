pragma solidity ^0.5.11;

import "./Growdrop.sol";
import "./CTokenInterface.sol";
import "./EIP20Interface.sol";

contract GrowdropCall {
    Growdrop growdrop;

    mapping(address => bool) public CheckOwner;

    constructor(address payable _Growdrop) public {
        growdrop = Growdrop(_Growdrop);
        CheckOwner[msg.sender] = true;
    }

    function addOwner(address _Owner) public {
        require(CheckOwner[msg.sender], "not owner");
        CheckOwner[_Owner] = !CheckOwner[_Owner];
    }

    function setGrowdrop(address payable _Growdrop) public {
        require(CheckOwner[msg.sender], "not owner");
        growdrop = Growdrop(_Growdrop);
    }
    
    function getGrowdropData(uint256 _GrowdropCount) public view returns (
        address,
        address,
        uint256,
        uint256,
        uint256,
        bool
        ) {
        return (
            address(growdrop.GrowdropToken(_GrowdropCount)),
            growdrop.Beneficiary(_GrowdropCount),
            growdrop.GrowdropAmount(_GrowdropCount),
            growdrop.ToUniswapTokenAmount(_GrowdropCount),
            growdrop.ToUniswapInterestRate(_GrowdropCount),
            growdrop.AddToUniswap(_GrowdropCount)
        );
    }

    function getGrowdropStateData(uint256 _GrowdropCount) public view returns (
        uint256,
        uint256,
        bool,
        bool,
        uint256
    ) {
        return (
            growdrop.GrowdropStartTime(_GrowdropCount),
            growdrop.GrowdropEndTime(_GrowdropCount),
            growdrop.GrowdropStart(_GrowdropCount),
            growdrop.GrowdropOver(_GrowdropCount),
            growdrop.ExchangeRateOver(_GrowdropCount)==0 ? growdrop.CToken(_GrowdropCount).exchangeRateStored() : growdrop.ExchangeRateOver(_GrowdropCount)
        );
    }

    function getGrowdropAmountData(uint256 _GrowdropCount) public view returns (
        uint256,
        uint256,
        uint256,
        uint256,
        bool,
        uint256,
        uint256
    ) {
        return (
            growdrop.TotalCTokenAmount(_GrowdropCount),
            growdrop.TotalMintedAmount(_GrowdropCount),
            growdrop.CTokenPerAddress(_GrowdropCount, msg.sender),
            growdrop.InvestAmountPerAddress(_GrowdropCount, msg.sender),
            growdrop.WithdrawOver(_GrowdropCount, msg.sender),
            growdrop.ActualCTokenPerAddress(_GrowdropCount, msg.sender),
            growdrop.ActualPerAddress(_GrowdropCount, msg.sender)
        );
    }
    
    function getTokenInfo(uint256 _GrowdropCount) public view returns (uint256, uint256, uint256) {
        EIP20Interface token = EIP20Interface(growdrop.Token(_GrowdropCount));
        EIP20Interface growdropToken = EIP20Interface(growdrop.GrowdropToken(_GrowdropCount));
        return (
            token.balanceOf(msg.sender),
            token.allowance(msg.sender, address(growdrop)),
            address(growdropToken)==address(0x0) ? 0 : (growdrop.DonateId(_GrowdropCount)==0 ? growdropToken.allowance(msg.sender, address(growdrop)) : 1)
        );
    }
}