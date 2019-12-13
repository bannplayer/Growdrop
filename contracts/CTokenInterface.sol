pragma solidity ^0.5.11;

contract CTokenInterface {
    /**
     * @dev Compound CToken interface
     */
    function mint(uint mintAmount) external returns (uint _error);
    function redeem(uint redeemTokens) external returns (uint _error);
    function redeemUnderlying(uint redeemAmount) external returns (uint _error);
    function balanceOf(address owner) external view returns (uint256 balance);
    function exchangeRateStored() public view returns (uint);
    function transfer(address dst, uint256 amount) external returns (bool);
    function exchangeRateCurrent() public returns (uint);
}