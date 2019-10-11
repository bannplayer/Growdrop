pragma solidity ^0.5.11;

contract GrowdropManagerInterface {
    address public Owner;
    mapping(address => mapping(address => bool)) public CheckUserJoinedGrowdrop;
    function emitGrowdropActionEvent(bool ActionIdx, uint256 ActionTime) public returns (bool);
    function emitUserActionEvent(address From, uint256 Amount, uint256 ActionTime, uint256 ActionIdx, uint256 AddOrSubValue) public returns (bool);
}
