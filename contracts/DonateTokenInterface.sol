pragma solidity ^0.5.11;

contract DonateTokenInterface {
    /**
     * @dev DonateToken interface
     */
    mapping(uint256 => address) public DonateIdOwner;
    function mint(address supporter, address beneficiary, address token, uint256 amount, uint256 donateId) public returns (uint256);
}