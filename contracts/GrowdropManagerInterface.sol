pragma solidity ^0.5.11;

import "./DonateTokenInterface.sol";
import "./TokenswapInterface.sol";

contract GrowdropManagerInterface {
    DonateTokenInterface public DonateToken;
    TokenswapInterface public Tokenswap;
    address public Owner;
    mapping(address => bool) public CheckGrowdropContract;
    mapping(address => mapping(address => bool)) public CheckUserJoinedGrowdrop;
    function emitGrowdropActionEvent(address From, uint256 Amount, uint256 ActionTime, uint256 ActionIdx, uint256 AddOrSubValue) public returns (bool);
}