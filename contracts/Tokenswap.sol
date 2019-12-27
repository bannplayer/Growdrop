pragma solidity ^0.5.11;

import "./EIP20Interface.sol";
import "./UniswapFactoryInterface.sol";
import "./UniswapExchangeInterface.sol";
import "./KyberNetworkProxyInterface.sol";
import "./Growdrop.sol";

/**
 * @dev Implementation of ERC20 token adding liquidity, swapping and transferring with KyberSwap and Uniswap. 
 */
contract Tokenswap {
    
    /**
     * @notice Current UniswapFactory.
     */
    UniswapFactoryInterface UniswapFactory;
    
    /**
     * @notice Current KyberNetworkProxy.
     */
    KyberNetworkProxyInterface KyberNetworkProxy;
    
    /**
     * @notice UniswapExchange for adding liquidity one time.
     */
    UniswapExchangeInterface UniswapAddPoolTokenExchange;
    
    /**
     * @notice Current Kyber Eth Token.
     */
    EIP20Interface KyberEthToken;
    
    /**
     * @notice ERC20 token to change as ether for adding liquidity one time.
     */
    EIP20Interface EthSwapToken;
    
    /**
     * @notice ERC20 token for adding liquidity one time.
     */
    EIP20Interface UniswapAddPoolToken;
    
    /**
     * @notice Current deployed Growdrop.
     */
    Growdrop growdrop;
    
    /**
     * @notice Address of added liquidity receiver for adding liquidity one time.
     */
    address Beneficiary;
    
    /**
     * @notice Check whether address is admin.
     */
    mapping(address => bool) public CheckOwner;
    
    /**
     * @notice Amount of ERC20 token to add liquidity to Uniswap for one time.
     */
    uint256 UniswapAddPoolTokenAmount;
    
    /**
     * @notice Amount of ERC20 token to swap ether for adding liquidity to Uniswap one time.
     */
    uint256 EthSwapTokenAmount;
    
    /**
     * @notice Constant for calculation.
     */
    uint256 constant Precision = 10**18;
    
    /**
     * @notice Minimum amount to swap or transfer to KyberSwap.
     */
    uint256 public KyberSwapMinimum;
    
    /**
     * @notice Check whether token is registered by admin.
     */
    mapping (address => bool) CheckTokenAddress;
    
    
    /**
     * @dev Constructor, storing deployer as admin,
     * and setting UniswapFactory, KyberNetworkProxy and 'KyberSwapMinimum'
     * @param _Growdrop current Growdrop contract
     * @param uniswapFactoryAddress current UniswapFactory contract
     * @param kyberNetworkProxyAddress current KyberNetworkProxy contract
     * @param kyberSwapMinimum minimum amount to swap or transfer to KyberSwap
     */
    constructor (
        address payable _Growdrop,
        address uniswapFactoryAddress,
        address kyberNetworkProxyAddress,
        uint256 kyberSwapMinimum) public {

        CheckOwner[msg.sender] = true;
        
        growdrop = Growdrop(_Growdrop);
        UniswapFactory = UniswapFactoryInterface(uniswapFactoryAddress);
        KyberNetworkProxy = KyberNetworkProxyInterface(kyberNetworkProxyAddress);
        
        KyberSwapMinimum = kyberSwapMinimum;
        
        KyberEthToken = EIP20Interface(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    }
    
    /**
     * @dev Adds new admin address 
     * @param _Owner new admin address
     */
    function addOwner(address _Owner) public {
        require(CheckOwner[msg.sender], "not owner");
        CheckOwner[_Owner] = !CheckOwner[_Owner];
    }
    
    /**
     * @dev Set new Growdrop's deployed address. 
     * @param _Growdrop new Growdrop's deployed address
     */
    function setGrowdrop(address payable _Growdrop) public {
        require(CheckOwner[msg.sender], "not owner");
        growdrop = Growdrop(_Growdrop);
    }
    
    /**
     * @dev Register new ERC20 token address to swap and transfer with KyberSwap and Uniswap. 
     * @param tokenAddress new ERC20 token address to register
     */
    function addTokenAddress(address tokenAddress) public {
        require(CheckOwner[msg.sender], "not owner");
        CheckTokenAddress[tokenAddress] = true;
    }
    
    /**
     * @dev Swap ether to ERC20 token with KyberSwap.
     * If cannot be swapped, revert.
     * @param tokenAddress ERC20 token address to receive
     */
    function kyberswapEthToToken(address tokenAddress) public payable {
        uint256 minConversionRate;
        uint256 slippageRate;
        (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(KyberEthToken, EIP20Interface(tokenAddress), msg.value);
        require(slippageRate != 0, "kyberswap slippageRate error");
        uint256 destAmount = KyberNetworkProxy.swapEtherToToken.value(msg.value)(EIP20Interface(tokenAddress), minConversionRate);
        require(EIP20Interface(tokenAddress).transfer(msg.sender, destAmount), "transfer token error");
    }
    
    /**
     * @dev Get UniswapExchange of ERC20 token.
     * If UniswapExchange does not exist, then create UniswapExchange.
     * @param token ERC20 token address to get UniswapExchange
     * @return tokenExchangeAddr created or existing UniswapExchange address
     */
    function getUniswapExchangeAddress(address token) private returns (address) {
        address tokenExchangeAddr = UniswapFactory.getExchange(token);
        if(tokenExchangeAddr==address(0x0)) {
            tokenExchangeAddr = UniswapFactory.createExchange(token);
        }
        return tokenExchangeAddr;
    }
    
    /**
     * @dev Swap ERC20 token to ERC20 token.
     * If sending ERC20 token is not registered, revert.
     * If receiving ERC20 token is not registered, revert.
     * Swaps sending ERC20 token to ether and swaps ether to receiving ERC20 token.
     * @param fromTokenAddress ERC20 token address to send token to UniswapExchange
     * @param toTokenAddress ERC20 token address to receive token from UniswapExchange
     * @param fromTokenAmount ERC20 token amount to send token to UniswapExchange
     * @return token_amount ERC20 token amount to receive token from UniswapExchange
     */
    function uniswapToken(address fromTokenAddress, address toTokenAddress, uint256 fromTokenAmount) public returns (uint256) {
        require(CheckTokenAddress[fromTokenAddress] && CheckTokenAddress[toTokenAddress], "not checked token");

        UniswapExchangeInterface fromTokenEx = UniswapExchangeInterface(getUniswapExchangeAddress(fromTokenAddress));
        UniswapExchangeInterface toTokenEx = UniswapExchangeInterface(getUniswapExchangeAddress(toTokenAddress));
        EIP20Interface fromToken = EIP20Interface(fromTokenAddress);
        
        require(fromToken.transferFrom(msg.sender, address(this), fromTokenAmount), "transfer token error");
        uint256 eth_price = fromTokenEx.getTokenToEthInputPrice(fromTokenAmount);
        require(fromToken.approve(address(fromTokenEx), fromTokenAmount), "approve token error");
        require(eth_price == fromTokenEx.tokenToEthSwapInput(fromTokenAmount,eth_price,1739591241), "token to eth error");
        uint256 token_amount = toTokenEx.getEthToTokenInputPrice(eth_price);
        require(token_amount == toTokenEx.ethToTokenTransferInput.value(eth_price)(token_amount,1739591241,msg.sender), "eth to token error");
        return token_amount;
    }
    
    function Add(uint256 a, uint256 b) private pure returns (uint256) {
        require(a+b>=a, "add overflow");
        return a+b;
    }
    
    function Sub(uint256 a, uint256 b) private pure returns (uint256) {
        require(a>=b, "subtract overflow");
        return a-b;
    }
    
    function MulAndDiv(uint256 a, uint256 b, uint256 c) private pure returns (uint256) {
        uint256 temp = a*b;
        require(temp/b==a && c>0, "arithmetic error");
        return temp/c;
    }
    
    /**
     * @dev Add liquidity pool to UniswapExchange.
     * If there is no UniswapExchange, create it.
     * @param ethSwapTokenAddress ERC20 token address to swap ether to add liquidity
     * @param uniswapAddPoolTokenAddress ERC20 token address to add liquidity
     * @param beneficiary address to receive liquidity
     * @param ethSwapTokenAmount ERC20 token amount to swap ether to add liquidity
     * @param uniswapAddPoolTokenAmount ERC20 token amount to add liquidity
     * @return if adding liquidity pool success then return true, else return false
     */
    function addPoolToUniswap(
        address ethSwapTokenAddress,
        address uniswapAddPoolTokenAddress,
        address beneficiary,
        uint256 ethSwapTokenAmount,
        uint256 uniswapAddPoolTokenAmount) public returns (bool) {
        require(address(growdrop)==msg.sender, "not growdrop contract");
        
        UniswapAddPoolTokenExchange = UniswapExchangeInterface(getUniswapExchangeAddress(uniswapAddPoolTokenAddress));
        
        EthSwapToken = EIP20Interface(ethSwapTokenAddress);
        UniswapAddPoolToken = EIP20Interface(uniswapAddPoolTokenAddress);
        Beneficiary = beneficiary;
        EthSwapTokenAmount = ethSwapTokenAmount;
        UniswapAddPoolTokenAmount = uniswapAddPoolTokenAmount;
        
        if(ethSwapTokenAmount==0) {
            return false;
        }
        
        uint256 minConversionRate;
        uint256 slippageRate;
        (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(EthSwapToken, KyberEthToken, EthSwapTokenAmount);
        uint256 TokenToEthAmount = MulAndDiv(minConversionRate, EthSwapTokenAmount, Precision);
        //if 'EthSwapTokenAmount' cannot be swapped to ether, return false
        if(TokenToEthAmount<=KyberSwapMinimum || slippageRate == 0) {
            return false;
        }
        
        uint256 min_liquidity;
        uint256 eth_reserve = address(UniswapAddPoolTokenExchange).balance;
        uint256 total_liquidity = UniswapAddPoolTokenExchange.totalSupply();
        
        //if there is no liquidity in UniswapExchange, add both tokens all to liquidity
        if (total_liquidity==0) {
            min_liquidity = Add(eth_reserve,TokenToEthAmount);
            changeTokenToEth_AddLiquidity_Transfer(
                minConversionRate,
                EthSwapTokenAmount,
                TokenToEthAmount,
                min_liquidity,
                UniswapAddPoolTokenAmount
            );
        } else {
            //if not, calculate ether and token amount to add liquidity
            uint256 max_token;
            uint256 token_reserve = UniswapAddPoolToken.balanceOf(address(UniswapAddPoolTokenExchange));
            max_token = Add(MulAndDiv(token_reserve, TokenToEthAmount, eth_reserve),1);
            min_liquidity = MulAndDiv(total_liquidity, TokenToEthAmount, eth_reserve);
            //if max token amount calculated by calculated ether is bigger than current token amount, recalculate
            if(max_token>UniswapAddPoolTokenAmount) {
                //recalculate ether amount based on current token amount
                uint256 lowerEthAmount = MulAndDiv(eth_reserve, UniswapAddPoolTokenAmount-1, token_reserve);
                
                //recalculate token amount based on recalculated ether amount
                uint256 lowerTokenAmount;
                if(lowerEthAmount<=KyberSwapMinimum) {
                    (minConversionRate, lowerTokenAmount) = calculateTokenAmountByEthAmountKyber(address(0x0), KyberSwapMinimum);
                } else {
                    (minConversionRate, lowerTokenAmount) = calculateTokenAmountByEthAmountKyber(address(0x0), lowerEthAmount);
                }
                //if recalculated ether swapping token cannot be swapped or cannot be added to liquidity, return false 
                if(minConversionRate==0 || lowerEthAmount<1000000000) {
                    return false;
                }
                
                max_token = Add(MulAndDiv(token_reserve, lowerEthAmount, eth_reserve),1);
                min_liquidity = MulAndDiv(total_liquidity, lowerEthAmount, eth_reserve);
                
                //if not, add liquidity with recalculated ether and token
                changeTokenToEth_AddLiquidity_Transfer(
                    minConversionRate,
                    lowerTokenAmount,
                    lowerEthAmount,
                    min_liquidity,
                    max_token
                );

                require(EthSwapToken.transfer(Beneficiary, EthSwapTokenAmount-lowerTokenAmount), "transfer left interests error");
                require(UniswapAddPoolToken.transfer(Beneficiary, UniswapAddPoolTokenAmount-max_token), "transfer left growdrop error");
            } else {
                //if not, add all tokens and ether to liquidity
                changeTokenToEth_AddLiquidity_Transfer(
                    minConversionRate,
                    EthSwapTokenAmount,
                    TokenToEthAmount,
                    min_liquidity,
                    max_token
                );
                require(UniswapAddPoolToken.transfer(Beneficiary, UniswapAddPoolTokenAmount-max_token), "transfer left growdrop error");
            }
        }
        return true;
    }
    
    /**
     * @dev Calculate ERC20 token amount to send with ether amount input using KyberSwap
     * @param ethSwapTokenAddress ERC20 token address to swap ether
     * @param ethAmount ether amount to use as input
     * @return minConversionRate KyberSwap's conversion rate. if can be swapped, return value with not 0, else return 0
     * @return tokenAmount KyberSwap's sending token amount. if can be swapped, return value with not 0, else return 0
     */
    function calculateTokenAmountByEthAmountKyber(address ethSwapTokenAddress, uint256 ethAmount) private view returns (uint256, uint256) {
        EIP20Interface ethSwapToken = EthSwapToken;
        if(ethSwapTokenAddress!=address(0x0)) {
            ethSwapToken = EIP20Interface(ethSwapTokenAddress);
        }
        
        uint256 minConversionRate;
        uint256 slippageRate;
        (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(ethSwapToken, KyberEthToken, Precision);
        
        uint256 precisionMinConversionRate = minConversionRate;
        uint256 tokenAmount = MulAndDiv(ethAmount, Precision, minConversionRate);
        
        (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(ethSwapToken, KyberEthToken, tokenAmount);
        if(slippageRate==0) {
            return (0, 0);
        }
        
        uint256 approximateEth = MulAndDiv(tokenAmount,minConversionRate,Precision);
        uint256 reapproximateEth = ethAmount*2;
        require(reapproximateEth>ethAmount, "multiply overflow");
        
        tokenAmount = MulAndDiv(
            Sub(reapproximateEth,approximateEth),
            Precision,
            precisionMinConversionRate
        );
        (minConversionRate,slippageRate) = KyberNetworkProxy.getExpectedRate(ethSwapToken, KyberEthToken, tokenAmount);
        reapproximateEth = MulAndDiv(minConversionRate, tokenAmount, Precision);
        
        if(slippageRate==0 || reapproximateEth<KyberSwapMinimum) {
            return (0, 0);
        }
        return (minConversionRate, tokenAmount);
    }
    
    /**
     * @dev Calculate expected ERC20 token or ether amount to be swapped with input.
     * @param ethOrToken if true, calculate ether to ERC20 token amount, else calculate ERC20 token to ether amount
     * @param tokenAddress ERC20 token address to swap or be swapped
     * @param Amount ERC20 token or ether amount to swap or be swapped
     * @return if can be swapped, return ERC20 token or ether amount, else return 0
     */
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
    
    /**
     * @dev Get UniswapExchange's liquidity pool with ERC20 token address.
     * @param tokenAddress ERC20 token address to get UniswapExchange
     * @return uniswapExchangeAddress.balance ether amount of UniswapExchange liquidity
     * @return EIP20Interface(tokenAddress).balanceOf(uniswapExchangeAddress) ERC20 token amount of UniswapExchange liquidity
     */
    function getUniswapLiquidityPool (address tokenAddress) public view returns (uint256, uint256) {
        address uniswapExchangeAddress = UniswapFactory.getExchange(tokenAddress);
        if(uniswapExchangeAddress==address(0x0)) {
            return (0,0);
        }
        return (uniswapExchangeAddress.balance, EIP20Interface(tokenAddress).balanceOf(uniswapExchangeAddress));
    }
    
    /**
     * @dev Swap ERC20 token to ether and add liquidity to UniswapExchange.
     * Liquidity is sended to 'beneficiary'.
     * @param minConversionRate KyberSwap's conversion rate to swap ERC20 token to ether
     * @param ethSwapTokenAmount ERC20 token amount to swap to ether
     * @param ethAmount ether amount to add liquidity to UniswapExchange
     * @param liquidity calculated minimum liquidity to add liquidity to UniswapExchange
     * @param max_token ERC20 token amount to add liquidity to UniswapExchange
     */
    function changeTokenToEth_AddLiquidity_Transfer(
        uint256 minConversionRate,
        uint256 ethSwapTokenAmount,
        uint256 ethAmount,
        uint256 liquidity,
        uint256 max_token) private {
        require(EthSwapToken.transferFrom(msg.sender, address(this), EthSwapTokenAmount), "transfer interests error");
        require(UniswapAddPoolToken.transferFrom(msg.sender, address(this), UniswapAddPoolTokenAmount), "transfer growdrop error");
            
        require(EthSwapToken.approve(address(KyberNetworkProxy), ethSwapTokenAmount), "approve token error");
        uint256 destAmount = KyberNetworkProxy.swapTokenToEther(EthSwapToken, ethSwapTokenAmount, minConversionRate);
        address(uint160(Beneficiary)).transfer(destAmount-ethAmount);
        
        require(UniswapAddPoolToken.approve(address(UniswapAddPoolTokenExchange),max_token), "approve growdrop error");
        require(liquidity==UniswapAddPoolTokenExchange.addLiquidity.value(ethAmount)(liquidity,max_token,1739591241), "add liquidity pool error");
        require(UniswapAddPoolTokenExchange.transfer(Beneficiary, liquidity), "transfer liquidity error");
    }
    
    /**
     * @dev Receive ether. Do nothing.
     */
    function () external payable {
        
    }
}