pragma solidity ^0.5.11;

import "./Growdrop.sol";

contract GrowdropCall {
    
    function getGrowdropData(address payable _Growdrop) public view returns (
        address,
        address,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        bool,
        bool,
        uint256,
        uint256,
        uint256,
        uint256
        ) {
        Growdrop temp = Growdrop(_Growdrop);
        return (
            address(temp.GrowdropToken()),
            temp.Beneficiary(),
            temp.GrowdropAmount(),
            temp.GrowdropStartTime(),
            temp.GrowdropEndTime(),
            temp.TotalCTokenAmount(),
            temp.TotalMintedAmount(),
            temp.GrowdropOver(),
            temp.GrowdropStart(),
            temp.ToUniswapTokenAmount(),
            temp.ToUniswapInterestRate(),
            temp.CTokenPerAddress(msg.sender),
            temp.InvestAmountPerAddress(msg.sender)
        );
    }
}