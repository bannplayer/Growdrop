pragma solidity ^0.5.11;

import "./EIP20Interface.sol";
import "./UniswapFactoryInterface.sol";
import "./UniswapExchangeInterface.sol";
import "./KyberNetworkProxyInterface.sol";
import "./GrowdropManagerInterface.sol";

contract Tokenswap {
    UniswapFactoryInterface UniswapFactory;
    KyberNetworkProxyInterface KyberNetworkProxy;
    UniswapExchangeInterface UniswapAddPoolTokenExchange;
    EIP20Interface KyberEthToken;
    EIP20Interface EthSwapToken;
    EIP20Interface UniswapAddPoolToken;
    GrowdropManagerInterface GrowdropManager;
    address Beneficiary;
    address Owner;
    
    uint256 UniswapAddPoolTokenAmount;
    uint256 EthSwapTokenAmount;
    
    uint256 constant Precision = 10**18;
    //should be 10**15, only for kovan 10**9
    uint256 public KyberSwapMinimum;

    mapping (address => bool) CheckTokenAddress;
    
    constructor (address GrowdropManagerAddress, address uniswapFactoryAddress, address kyberNetworkProxyAddress, address tokenAddress1, address tokenAddress2, uint256 kyberSwapMinimum) public {
        Owner=msg.sender;
        
        GrowdropManager = GrowdropManagerInterface(GrowdropManagerAddress);
        UniswapFactory = UniswapFactoryInterface(uniswapFactoryAddress);
        KyberNetworkProxy = KyberNetworkProxyInterface(kyberNetworkProxyAddress);
        CheckTokenAddress[tokenAddress1]=true;
        CheckTokenAddress[tokenAddress2]=true;
        
        KyberSwapMinimum = kyberSwapMinimum;
        
        KyberEthToken = EIP20Interface(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    }
    
    function setGrowdropManager(address GrowdropManagerAddress) public returns (bool) {
        require(msg.sender==Owner);
        GrowdropManager=GrowdropManagerInterface(GrowdropManagerAddress);
        return true;
    }

    function addTokenAddress(address tokenAddress) public {
        require(msg.sender==Owner);
        CheckTokenAddress[tokenAddress]=true;
    }
    
    function kyberswapEthToToken(address tokenAddress) public payable {
        uint256 minConversionRate;
        uint256 slippageRate;
        (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(KyberEthToken, EIP20Interface(tokenAddress), msg.value);
        require(slippageRate!=0);
        uint256 destAmount = KyberNetworkProxy.swapEtherToToken.value(msg.value)(EIP20Interface(tokenAddress), minConversionRate);
        require(EIP20Interface(tokenAddress).transfer(msg.sender, destAmount));
    }
    
    function getUniswapExchangeAddress(address token) private returns (address) {
        address tokenExchangeAddr = UniswapFactory.getExchange(token); 
        if(tokenExchangeAddr==address(0x0)) {
            tokenExchangeAddr = UniswapFactory.createExchange(token);
        }
        return tokenExchangeAddr;
    }
    
    function uniswapToken(address fromTokenAddress, address toTokenAddress, uint256 fromTokenAmount) public returns (uint256) {
        require(CheckTokenAddress[fromTokenAddress] && CheckTokenAddress[toTokenAddress]);

        UniswapExchangeInterface fromTokenEx = UniswapExchangeInterface(getUniswapExchangeAddress(fromTokenAddress));
        UniswapExchangeInterface toTokenEx = UniswapExchangeInterface(getUniswapExchangeAddress(toTokenAddress));
        EIP20Interface fromToken = EIP20Interface(fromTokenAddress);
        
        require(fromToken.transferFrom(msg.sender, address(this), fromTokenAmount));
        uint256 eth_price = fromTokenEx.getTokenToEthInputPrice(fromTokenAmount);
        require(fromToken.approve(address(fromTokenEx), fromTokenAmount));
        require(eth_price == fromTokenEx.tokenToEthSwapInput(fromTokenAmount,eth_price,1739591241));
        uint256 token_amount = toTokenEx.getEthToTokenInputPrice(eth_price);
        require(token_amount == toTokenEx.ethToTokenTransferInput.value(eth_price)(token_amount,1739591241,msg.sender));
        return token_amount;
    }
    
    function Add(uint256 a, uint256 b) private pure returns (uint256) {
        require(a+b>=a);
        return a+b;
    }
    
    function Sub(uint256 a, uint256 b) private pure returns (uint256) {
        require(a>=b);
        return a-b;
    }
    
    function MulAndDiv(uint256 a, uint256 b, uint256 c) private pure returns (uint256) {
        uint256 temp = a*b;
        require(temp/b==a);
        require(c>0);
        return temp/c;
    }
    
    function addPoolToUniswap(address ethSwapTokenAddress, address uniswapAddPoolTokenAddress, address beneficiary, uint256 ethSwapTokenAmount, uint256 uniswapAddPoolTokenAmount) public returns (bool) {
        require(GrowdropManager.CheckGrowdropContract(msg.sender));
        UniswapAddPoolTokenExchange=UniswapExchangeInterface(getUniswapExchangeAddress(uniswapAddPoolTokenAddress));
        
        EthSwapToken = EIP20Interface(ethSwapTokenAddress);
        UniswapAddPoolToken = EIP20Interface(uniswapAddPoolTokenAddress);
        Beneficiary=beneficiary;
        EthSwapTokenAmount = ethSwapTokenAmount;
        UniswapAddPoolTokenAmount = uniswapAddPoolTokenAmount;
        
        require(EthSwapToken.transferFrom(msg.sender, address(this), EthSwapTokenAmount));
        require(UniswapAddPoolToken.transferFrom(msg.sender, address(this), UniswapAddPoolTokenAmount));
        
        uint256 minConversionRate;
        uint256 slippageRate;
        (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(EthSwapToken, KyberEthToken, EthSwapTokenAmount);
        uint256 TokenToEthAmount = MulAndDiv(minConversionRate, EthSwapTokenAmount, Precision);
        if(TokenToEthAmount<=KyberSwapMinimum || slippageRate == 0) {
            require(EthSwapToken.transfer(Beneficiary, EthSwapTokenAmount));
            require(UniswapAddPoolToken.transfer(Beneficiary, UniswapAddPoolTokenAmount));
            return false;
        }
        
        uint256 min_liquidity;
        uint256 eth_reserve = address(UniswapAddPoolTokenExchange).balance;
        uint256 total_liquidity = UniswapAddPoolTokenExchange.totalSupply();
        
        if (total_liquidity==0) {
            min_liquidity = Add(eth_reserve,TokenToEthAmount);
            changeTokenToEth_AddLiquidity_Transfer(minConversionRate, EthSwapTokenAmount, TokenToEthAmount,min_liquidity,UniswapAddPoolTokenAmount);
        } else {
            uint256 max_token;
            uint256 token_reserve = UniswapAddPoolToken.balanceOf(address(UniswapAddPoolTokenExchange));
            max_token = Add(MulAndDiv(TokenToEthAmount, token_reserve, eth_reserve),1);
            min_liquidity = MulAndDiv(TokenToEthAmount, total_liquidity, eth_reserve);
            if(max_token>UniswapAddPoolTokenAmount) {
                uint256 lowerEthAmount = MulAndDiv(Sub(UniswapAddPoolTokenAmount,1), eth_reserve, token_reserve);
                max_token = Add(MulAndDiv(lowerEthAmount, token_reserve, eth_reserve),1);
                min_liquidity = MulAndDiv(lowerEthAmount, total_liquidity, eth_reserve);
                
                uint256 lowerTokenAmount;
                if(lowerEthAmount<=KyberSwapMinimum) {
                    (minConversionRate, lowerTokenAmount) = calculateTokenAmountByEthAmountKyber(address(0x0), KyberSwapMinimum);
                } else {
                    (minConversionRate, lowerTokenAmount) = calculateTokenAmountByEthAmountKyber(address(0x0), lowerEthAmount);
                }
                if(minConversionRate==0) {
                    require(EthSwapToken.transfer(Beneficiary, EthSwapTokenAmount));
                    require(UniswapAddPoolToken.transfer(Beneficiary, UniswapAddPoolTokenAmount));
                    return false;
                }
                
                changeTokenToEth_AddLiquidity_Transfer(minConversionRate, lowerTokenAmount, lowerEthAmount, min_liquidity, max_token);

                require(EthSwapToken.transfer(Beneficiary, EthSwapTokenAmount-lowerTokenAmount));
                require(UniswapAddPoolToken.transfer(Beneficiary, UniswapAddPoolTokenAmount-max_token));
            } else {
                changeTokenToEth_AddLiquidity_Transfer(minConversionRate, EthSwapTokenAmount, TokenToEthAmount,min_liquidity,max_token);
                require(UniswapAddPoolToken.transfer(Beneficiary, UniswapAddPoolTokenAmount-max_token));
            }
        }
        return true;
    }
    
    function calculateTokenAmountByEthAmountKyber(address ethSwapTokenAddress, uint256 ethAmount) private view returns (uint256, uint256) {
        EIP20Interface ethSwapToken = EthSwapToken;
        if(ethSwapTokenAddress!=address(0x0)) {
            ethSwapToken = EIP20Interface(ethSwapTokenAddress);
        }
        
        uint256 minConversionRate;
        uint256 slippageRate;
        (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(ethSwapToken, KyberEthToken, Precision);
        
        uint256 precisionMinConversionRate=minConversionRate;
        uint256 tokenAmount = MulAndDiv(ethAmount, Precision, minConversionRate);
        
        (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(ethSwapToken, KyberEthToken, tokenAmount);
        if(slippageRate==0) {
            return (0, 0);
        }
        
        uint256 approximateEth = MulAndDiv(tokenAmount,minConversionRate,Precision);
        uint256 reapproximateEth=ethAmount*2;
        require(reapproximateEth>ethAmount);
        
        tokenAmount = MulAndDiv(Sub(reapproximateEth,approximateEth), Precision, precisionMinConversionRate);
        (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(ethSwapToken, KyberEthToken, tokenAmount);
        reapproximateEth=MulAndDiv(tokenAmount, minConversionRate, Precision);
        
        if(slippageRate==0 || reapproximateEth<KyberSwapMinimum) {
            return (0, 0);
        }
        return (minConversionRate, tokenAmount);
    }
    
    function getExpectedAmount(bool ethOrToken, address tokenAddress, uint256 Amount) public view returns (uint256) {
        uint256 minConversionRate;
        uint256 slippageRate;
        if(ethOrToken) {
            (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(KyberEthToken, EIP20Interface(tokenAddress), Amount);
        } else {
            (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(EIP20Interface(tokenAddress), KyberEthToken, Amount);
        }
        if(slippageRate==0) {
            return 0;
        }
        return MulAndDiv(minConversionRate, Amount, Precision);
    }
    
    function getUniswapLiquidityPool (address tokenAddress) public view returns (uint256, uint256) {
        address uniswapExchangeAddress = UniswapFactory.getExchange(tokenAddress);
        if(uniswapExchangeAddress==address(0x0)) {
            return (0,0);
        }
        return (uniswapExchangeAddress.balance, EIP20Interface(tokenAddress).balanceOf(uniswapExchangeAddress));
    }
    
    function changeTokenToEth_AddLiquidity_Transfer(uint256 minConversionRate, uint256 ethSwapTokenAmount, uint256 ethAmount, uint256 liquidity, uint256 max_token) private {
        require(EthSwapToken.approve(address(KyberNetworkProxy), ethSwapTokenAmount));
        uint256 destAmount = KyberNetworkProxy.swapTokenToEther(EthSwapToken, ethSwapTokenAmount, minConversionRate);
        address(uint160(Beneficiary)).transfer(destAmount-ethAmount);
        
        require(UniswapAddPoolToken.approve(address(UniswapAddPoolTokenExchange),max_token));
        require(liquidity==UniswapAddPoolTokenExchange.addLiquidity.value(ethAmount)(liquidity,max_token,1739591241));
        require(UniswapAddPoolTokenExchange.transfer(Beneficiary, liquidity));
    }
    
    function () external payable {
        
    }
}