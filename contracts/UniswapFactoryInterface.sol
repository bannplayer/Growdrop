pragma solidity ^0.5.11;

contract UniswapFactoryInterface {
    /**
     * @dev UniswapFactory interface
     */
    function createExchange(address token) external returns (address exchange);
    function getExchange(address token) external view returns (address exchange);
}