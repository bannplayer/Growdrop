pragma solidity ^0.5.11;

import "./EIP20Interface.sol";
import "./UniswapFactoryInterface.sol";
import "./UniswapExchangeInterface.sol";
import "./SafeMath.sol";
import "./Growdrop.sol";

//only for kovan testing

contract UniswapDaiSwap {
    using SafeMath for uint256;
    UniswapFactoryInterface public factory;
    UniswapExchangeInterface public compoundDaiEx;
    UniswapExchangeInterface public kyberDaiEx;
    EIP20Interface public compoundDai;
    EIP20Interface public kyberDai;
    constructor() public {
        compoundDai = EIP20Interface(0xbF7A7169562078c96f0eC1A8aFD6aE50f12e5A99);
        kyberDai = EIP20Interface(0xC4375B7De8af5a38a93548eb8453a498222C4fF2);
        factory=UniswapFactoryInterface(0xD3E51Ef092B2845f10401a0159B2B96e8B6c3D30);
        if(factory.getExchange(0xbF7A7169562078c96f0eC1A8aFD6aE50f12e5A99)==address(0x0)) {
            compoundDaiEx=UniswapExchangeInterface(factory.createExchange(0xbF7A7169562078c96f0eC1A8aFD6aE50f12e5A99));
        } else {
            compoundDaiEx=UniswapExchangeInterface(factory.getExchange(0xbF7A7169562078c96f0eC1A8aFD6aE50f12e5A99));
        }
        if(factory.getExchange(0xC4375B7De8af5a38a93548eb8453a498222C4fF2)==address(0x0)) {
            kyberDaiEx=UniswapExchangeInterface(factory.createExchange(0xC4375B7De8af5a38a93548eb8453a498222C4fF2));
        } else {
            kyberDaiEx=UniswapExchangeInterface(factory.getExchange(0xC4375B7De8af5a38a93548eb8453a498222C4fF2));
        }
    }
    
    function addPool(address exchangeAddress, address tokenAddress, uint256 tokenAmount) public payable returns (bool) {
        UniswapExchangeInterface Ex = UniswapExchangeInterface(exchangeAddress);
        EIP20Interface token = EIP20Interface(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), tokenAmount));
        if(Ex.totalSupply()==0) {
            uint256 min_liquidity = address(Ex).balance.add(msg.value);
            require(token.approve(address(Ex),tokenAmount));
            require(min_liquidity==Ex.addLiquidity.value(msg.value)(min_liquidity,tokenAmount,1739591241));
            require(Ex.transfer(msg.sender, min_liquidity));
        } else {
            uint256 eth_reserve = address(Ex).balance;
            uint256 token_reserve = token.balanceOf(address(Ex));
            uint256 total_liquidity = Ex.totalSupply();
            uint256 max_token = MulAndDiv(msg.value, token_reserve, eth_reserve).add(1);
            uint256 min_liquidity = MulAndDiv(msg.value, total_liquidity, eth_reserve);
            require(token.approve(address(Ex),max_token));
            require(min_liquidity==Ex.addLiquidity.value(msg.value)(min_liquidity,max_token,1739591241));
            require(Ex.transfer(msg.sender, min_liquidity));
            require(token.transfer(msg.sender, token.balanceOf(address(this))));
            msg.sender.transfer(address(this).balance);
        }
        return true;
    }
    
    function swapDAICompoundToKyber(uint256 amount) public returns (uint256) {
        require(compoundDai.transferFrom(msg.sender, address(this), amount));
        uint256 eth_price = compoundDaiEx.getTokenToEthInputPrice(amount);
        require(compoundDai.approve(address(compoundDaiEx), amount));
        require(eth_price == compoundDaiEx.tokenToEthSwapInput(amount, eth_price,1739591241));
        uint256 token_amount = kyberDaiEx.getEthToTokenInputPrice(eth_price);
        require(token_amount == kyberDaiEx.ethToTokenTransferInput.value(eth_price)(token_amount,1739591241,msg.sender));
        return token_amount;
    }
    
    function getPool (address exchangeAddress, address tokenAddress) public view returns (uint256, uint256) {
        return (exchangeAddress.balance, EIP20Interface(tokenAddress).balanceOf(exchangeAddress));
    }
    
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
    
    function() external payable {
        
    }
}
