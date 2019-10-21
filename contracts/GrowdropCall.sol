pragma solidity ^0.5.11;

import "./SafeMath.sol";
import "./Growdrop.sol";

contract GrowdropCall {
    using SafeMath for uint256;
    
    function MulAndDiv(uint256 a, uint256 b, uint256 c) private pure returns (uint256) {
        return a.mul(b).div(c);
    }
    
    function getGrowdropData(address payable _Growdrop) public view returns (address, address, uint256, uint256, uint256, uint256, uint256, bool, bool, uint256, uint256) {
        Growdrop temp = Growdrop(_Growdrop);
        return (address(temp.GrowdropToken()), temp.Beneficiary(), temp.GrowdropAmount(), temp.GrowdropStartTime(), temp.GrowdropEndTime(), temp.TotalBalance(), temp.TotalMintedAmount(), temp.GrowdropOver(), temp.GrowdropStart(), temp.ToUniswapTokenAmount(), temp.ToUniswapInterestRate());
    }
    
    function getUserData(address payable _Growdrop) public view returns (uint256, uint256, uint256, uint256, uint256) {
        Growdrop temp = Growdrop(_Growdrop);
        return (temp.InvestAmountPerAddress(msg.sender), temp.TotalPerAddress(msg.sender), temp.TotalPerAddress(msg.sender).sub(temp.InvestAmountPerAddress(msg.sender)), temp.InterestRate(msg.sender), MulAndDiv(temp.InterestRate(msg.sender), temp.GrowdropAmount(), 10**18));
    }
}