pragma solidity ^0.5.11;

import "./EIP20Interface.sol";

contract KyberNetworkProxyInterface {
    function getExpectedRate(EIP20Interface src, EIP20Interface dest, uint srcQty) public view returns (uint expectedRate, uint slippageRate);
    function swapTokenToEther(EIP20Interface token, uint srcAmount, uint minConversionRate) public returns (uint);
}
