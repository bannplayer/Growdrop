pragma solidity ^0.5.11;

import "./Growdrop.sol";

contract GrowdropCall {
    Growdrop growdrop;

    mapping(address => bool) public CheckOwner;

    constructor(address payable _Growdrop) public {
        growdrop = Growdrop(_Growdrop);
        CheckOwner[msg.sender] = true;
    }

    function addOwner(address _Owner) public {
        require(CheckOwner[msg.sender]);
        CheckOwner[_Owner] = !CheckOwner[_Owner];
    }

    function setGrowdrop(address payable _Growdrop) public {
        require(CheckOwner[msg.sender]);
        growdrop = Growdrop(_Growdrop);
    }
    
    function getGrowdropData(uint256 _GrowdropCount) public view returns (
        address,
        address,
        uint256,
        uint256,
        uint256
        ) {
        return (
            address(growdrop.GrowdropToken(_GrowdropCount)),
            growdrop.Beneficiary(_GrowdropCount),
            growdrop.GrowdropAmount(_GrowdropCount),
            growdrop.ToUniswapTokenAmount(_GrowdropCount),
            growdrop.ToUniswapInterestRate(_GrowdropCount)
        );
    }

    function getGrowdropStateData(uint256 _GrowdropCount) public view returns (
        uint256,
        uint256,
        bool,
        bool
    ) {
        return (
            growdrop.GrowdropStartTime(_GrowdropCount),
            growdrop.GrowdropEndTime(_GrowdropCount),
            growdrop.GrowdropStart(_GrowdropCount),
            growdrop.GrowdropOver(_GrowdropCount)
        );
    }

    function getGrowdropAmountData(uint256 _GrowdropCount) public view returns (
        uint256,
        uint256,
        uint256,
        uint256
    ) {
        return (
            growdrop.TotalCTokenAmount(_GrowdropCount),
            growdrop.TotalMintedAmount(_GrowdropCount),
            growdrop.CTokenPerAddress(_GrowdropCount, msg.sender),
            growdrop.InvestAmountPerAddress(_GrowdropCount, msg.sender)
        );
    }
}