pragma solidity ^0.5.11;

import "./EIP20Interface.sol";

contract KyberNetworkProxyInterface {
    /**
     * @dev KyberNetworkProxy interface
     */
    function getExpectedRate(EIP20Interface src, EIP20Interface dest, uint srcQty) public view returns (uint expectedRate, uint slippageRate);
    function swapTokenToEther(EIP20Interface token, uint srcAmount, uint minConversionRate) public returns (uint);
    function swapEtherToToken(EIP20Interface token, uint minConversionRate) public payable returns (uint);
}