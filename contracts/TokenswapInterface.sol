pragma solidity ^0.5.11;

contract TokenswapInterface {
    /**
     * @dev Tokenswap interface
     */
    function kyberswapEthToToken(address tokenAddress) public payable returns (bool);
    function uniswapToken(address fromTokenAddress, address toTokenAddress, uint256 fromTokenAmount) public returns (uint256);
    function addPoolToUniswap(address ethSwapTokenAddress, address uniswapAddPoolTokenAddress, address beneficiary, uint256 ethSwapTokenAmount, uint256 uniswapAddPoolTokenAmount) public returns (bool);
    function calculateTokenAmountByEthAmountKyber(address ethSwapTokenAddress, uint256 ethAmount) public view returns (uint256, uint256);
}