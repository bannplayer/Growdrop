import Web3 from "web3";
import GrowdropManagerArtifact from "../../build/contracts/GrowdropManager.json";
import GrowdropArtifact from "../../build/contracts/Growdrop.json";
import EIP20Interface from "../../build/contracts/EIP20Interface.json";
import SimpleTokenABI from "./SimpleTokenABI.json";
import DonateToken from "../../build/contracts/DonateToken.json";
import Tokenswap from "../../build/contracts/Tokenswap.json";
import GrowdropCall from "../../build/contracts/GrowdropCall.json";
import KyberNetworkProxy from "../../build/contracts/KyberNetworkProxyInterface.json";
import Torus from "@toruslabs/torus-embed";
import bs58 from 'bs58';
var bigdecimal = require("bigdecimal");
var ipfsClient = require('ipfs-http-client');

const App = {
  web3: null,
  account: null,
  DAI: null,
  KyberDAI: null,
  Growdrop: null,
  SimpleToken: null,
  GrowdropManager: null,
  DonateToken: null,
  Tokenswap: null,
  GrowdropCall: null,
  KyberNetworkProxy: null,
  UniswapSimpleTokenExchangeAddress: "0xfC8c8f7040b3608A74184D664853f5f30F53CbA8",
  DAIAddress:"0xbF7A7169562078c96f0eC1A8aFD6aE50f12e5A99",
  KyberDAIAddress:"0xC4375B7De8af5a38a93548eb8453a498222C4fF2",
  KyberNetworkProxyAddress: "0x692f391bCc85cefCe8C237C01e1f636BbD70EA4D",
  SimpleTokenAddress: "0x53cc0b020c7c8bbb983d0537507d2c850a22fa4c",
  KyberEthTokenAddress: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
  cDAIAddress: "0x0a1e4d0b5c71b955c0a5993023fc48ba6e380496",

  MetamaskLogin: async function() {
    App.setStatus("login to metamask... please wait");
    await App.MetamaskProvider();
    await App.start();
    App.setStatus("login to metamask done");
  },

  TorusLogin: async function() {
    App.setStatus("login to torus... please wait");
    await App.TorusProvider();
    await App.start();
    App.setStatus("login to torus done");
  },

  MetamaskProvider: async function() {
    if (window.ethereum) {
      App.web3 = new Web3(window.ethereum);
      await window.ethereum.enable();
    } else if (window.web3) {
      App.web3 = new Web3(window.web3.currentProvider);
    }
  },

  TorusProvider: async function() {
    const torus = new Torus();
    await torus.init({
      network: {
        host: 'kovan',
        chainId: 42,
        networkName: 'kovan Test Network'
      }
    /*
      network: {
        host: 'mainnet',
        chainId: 1,
        networkName: 'Main Ethereum Network'
      }
    */
    });
    await torus.login();
    App.web3 = await new Web3(torus.provider);
  },

  SimpleTokenMint: async function() {
    return await App.SimpleToken.methods.mint().send({from:App.account});
  },

  withDecimal: function(number) {
    return String(App.toBigInt(number).divide(new bigdecimal.BigDecimal("1000000000000000000")));
  },

  toBigInt: function(number) {
    return new bigdecimal.BigDecimal(String(number));
  },

  /*
  new contract instance
  abi => contract abi (json type)
  address => contract address (String)
  return => contract instance
  */
  contractInit: function(abi, address) {
    const { web3 } = App;
    return new web3.eth.Contract(abi, address);
  },

  /*
  get metamask current account (address)
  return => metamask current account address (String)
  */
  getProviderCurrentAccount: async function () {
    const { web3 } = App;
    const accounts = await web3.eth.getAccounts();
    return accounts[0];
  },

  /*
  get balance of account
  account => account address to get balance (String)
  return => account eth balance (Number)
  */
  GetBalanceCall: async function (account) {
    const { web3 } = App;
    return await web3.eth.getBalance(account);
  },

  start: async function() {
    const { web3 } = this;
    
    const networkId = await web3.eth.net.getId();
    if(networkId==1) {
      //UniswapSimpleTokenExchangeAddress="0xfC8c8f7040b3608A74184D664853f5f30F53CbA8";
      DAIAddress="0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359";
      KyberDAIAddress="0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359";
      KyberNetworkProxyAddress="0x818E6FECD516Ecc3849DAf6845e3EC868087B755";
      //SimpleTokenAddress="0x53cc0b020c7c8bbb983d0537507d2c850a22fa4c";
      KyberEthTokenAddress="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
      cDAIAddress="0xf5dce57282a584d2746faf1593d3121fcac444dc";
    }
    const deployedNetwork_growdropmanager = GrowdropManagerArtifact.networks[networkId];
    const deployedNetwork_donatetoken = DonateToken.networks[networkId];
    const deployedNetwork_tokenswap = Tokenswap.networks[networkId];
    const deployedNetwork_growdropcall = GrowdropCall.networks[networkId];

    this.GrowdropManager = this.contractInit(GrowdropManagerArtifact.abi, deployedNetwork_growdropmanager.address);
    this.DonateToken = this.contractInit(DonateToken.abi, deployedNetwork_donatetoken.address);
    this.Tokenswap = this.contractInit(Tokenswap.abi, deployedNetwork_tokenswap.address);
    this.GrowdropCall = this.contractInit(GrowdropCall.abi, deployedNetwork_growdropcall.address);
    
    this.DAI = this.contractInit(EIP20Interface.abi, this.DAIAddress);
    this.KyberDAI = this.contractInit(EIP20Interface.abi, this.KyberDAIAddress);
    this.KyberNetworkProxy = this.contractInit(KyberNetworkProxy.abi, this.KyberNetworkProxyAddress);
    this.ipfs = ipfsClient('ipfs.infura.io', '5001', {protocol:'https'})

    this.account = await this.getProviderCurrentAccount();
    await this.refreshFirst();
  },

  refreshFirst: async function() {
    this.SimpleToken = this.contractInit(SimpleTokenABI.abi, this.SimpleTokenAddress);
    await this.refreshGrowdrop();

    if(App.Growdrop!=null) {
      await this.refresh();
      App.getGrowdropActionPastEvents(App.GrowdropManager, App.Growdrop._address, App.account);  
    }
  },

  KyberswapEthToTokenTx: async function(contractinstance, token, amount, account) {
    return await contractinstance.methods.kyberswapEthToToken(token).send({from:account, value:amount})
    .then(receipt => {
      return (receipt.status==true);
    }).catch(error => {
      return false;
    }); 
  },

  UniswapTokenTx: async function(contractinstance, fromtoken, totoken, amount, account) {
    return await contractinstance.methods.uniswapToken(fromtoken, totoken, amount).send({from:account})
    .then(receipt => {
      return (receipt.status==true);
    }).catch(error => {
      return false;
    }); 
  },

  GetExpectedAmountCall: async function(contractinstance, ethortoken,token,amount) {
    return await contractinstance.methods.getExpectedAmount(ethortoken,token,amount).call();
  },

  GetUniswapLiquidityPoolCall: async function(contractinstance, token) {
    return await contractinstance.methods.getUniswapLiquidityPool(token).call();
  },

  DonateInfoToTokenAmountCall: async function(contractinstance, from, to, token, donateid) {
    return await contractinstance.methods.DonateInfoToTokenAmount(from,to,token,donateid).call();
  },

  MultihashToDonateIdCall: async function(contractinstance, hash, hashfunction, size) {
    return await contractinstance.methods.MultihashToDonateId(hash,hashfunction,size).call();
  },

  DonateIdOwnerCall: async function(contractinstance, tokenid) {
    return await contractinstance.methods.DonateIdOwner(tokenid).call();
  },

  GetMultihashCall: async function(contractinstance, donateid) {
    return await contractinstance.methods.getMultihash(donateid).call();
  },

  SetMultihashTx: async function(contractinstance,hash,hashfunction,size,account) {
    return await contractinstance.methods.setMultihash(hash,hashfunction,size).send({from:account})
    .then(receipt => {
      return (receipt.status==true);
    }).catch(error => {
      return false;
    }); 
  },
  /*
  Uniswap token to eth price call
  contractinstance => Uniswap Exchange contract instance 
  amount => amount of token to get eth price (Number)
  return => amount of eth (Number)
  */
  UniswapTokenToEthInputPriceCall: async function(contractinstance, amount) {
    return await contractinstance.methods.getTokenToEthInputPrice(amount).call();
  },

  /*
  ERC20 Token's balance call
  contractinstance => ERC20 contract instance 
  account => address to get balance of (String)
  return => account balance of ERC20 Token (Number)
  */
  TokenBalanceOfCall: async function(contractinstance, account) {
    return await contractinstance.methods.balanceOf(account).call();
  },

  /*
  ERC20 Token's allowance call (approved amount)
  contractinstance => ERC20 contract instance
  from => address who approved (String)
  to => address from approved to (String)
  return => approved amount of 'to' address from 'from' address
  */
  TokenAllowanceCall: async function(contractinstance, from, to) {
    return await contractinstance.methods.allowance(from, to).call();
  },

  /*
  Growdrop Contract Data call
  contractinstance => UniswapDaiSwap contract instance
  GrowdropAddress => Growdrop contract address
  return =>
  address of Growdrop Token Contract (String)
  address of beneficiary (String)
  selling amount of Growdrop Token (Number)
  Growdrop contract start time (Number unix timestamp)
  Growdrop contract end time (Number unix timestamp)
  Growdrop contract total interest + total invested amount (Number)
  Growdrop contract total invested amount (Number)
  Growdrop contract over (Boolean true : over, false : not over)
  Growdrop contract Start (Boolean true : start, false : not start)
  Growdrop token amount to uniswap pool (Number)
  Growdrop interest percentage to uniswap pool (Number 1~99)
  */
  GetGrowdropDataCall: async function(contractinstance, GrowdropAddress) {
    return await contractinstance.methods.getGrowdropData(GrowdropAddress).call();
  },

  /*
  Growdrop Contract's User Data call
  contractinstance => UniswapDaiSwap contract instance
  GrowdropAddress => Growdrop contract address (String)
  account => account to get User Data (String)
  return => 
  investor's invested amount to Growdrop contract (Number)
  investor's invested amount + accrued interest to Growdrop contract (Number)
  investor's accrued interest to Growdrop contract (Number)
  investor's interest percentage of total Growdrop contract interest (Number)
  investor's Growdrop token amount calculated by investor's interest percentage (Number)
  */
  GetUserDataCall: async function(contractinstance, GrowdropAddress, account) {
    return await contractinstance.methods.getUserData(GrowdropAddress).call({from: account});
  },

  /*
  Growdrop Contract List's Length call
  contractinstance => GrowdropManager contract instance
  return => 
  Growdrop contracts list length (Number)
  */
  GetGrowdropListLengthCall: async function(contractinstance) {
    return await contractinstance.methods.getGrowdropListLength().call();
  },

  /*
  Growdrop Contract address call
  contractinstance => GrowdropManager contract instance
  contractIdx => Growdrop contract index (Number)
  return =>
  Growdrop contract address (String)
  */
  GetGrowdropCall: async function(contractinstance, contractIdx) {
    return await contractinstance.methods.GrowdropList(contractIdx).call();
  },

  /*
  address's invested amount + accrued interest call
  contractinstance => Growdrop contract instance
  account => address to get data (String)
  return =>
  user's invested amount + accrued interest to Growdrop contract (Number)
  */
  TotalPerAddressCall: async function(contractinstance, account) {
    return await contractinstance.methods.TotalPerAddress(account).call();
  },

  /*
  address's invested amount call
  contractinstance => Growdrop contract instance
  account => address to get data (String)
  return =>
  user's invested amount to Growdrop contract (Number)
  */
  InvestAmountPerAddressCall: async function(contractinstance, account) {
    return await contractinstance.methods.InvestAmountPerAddress(account).call();
  },

  /*
  address's total invested amount call (all Growdrop contracts)
  contractinstance => GrowdropManager contract instance
  account => address to get data (String)
  return =>
  user's invested amount to all Growdrop contracts (Number)
  */
  TotalUserInvestedAmountCall: async function(contractinstance, account) {
    return await contractinstance.methods.TotalUserInvestedAmount(account).call();
  },

  /*
  Growdrop contract's total user count call
  contractinstance => GrowdropManager contract instance
  account => Growdrop contract address to get data (String)
  return =>
  user count to Growdrop contract (Number)
  */
  TotalUserCountCall: async function(contractinstance, account) {
    return await contractinstance.methods.TotalUserCount(account).call();
  },

  /*
  Growdrop contract's total invested amount call
  contractinstance => Growdrop contract instance
  return =>
  total invested amount to Growdrop contract (Number)
  */
  TotalMintedAmountCall: async function(contractinstance) {
    return await contractinstance.methods.TotalMintedAmount().call();
  },

  /*
  Growdrop contract's selling token contract address call
  contractinstance => Growdrop contract instance
  return =>
  address of Growdrop token contract (String)
  */
  GrowdropTokenCall: async function(contractinstance) {
    return await contractinstance.methods.GrowdropToken().call();
  },

  /*
  Growdrop contract's end time call
  contractinstance => Growdrop contract instance
  return => 
  Growdrop end time (Number unix timestamp)
  */
  GrowdropEndTimeCall: async function(contractinstance) {
    return await contractinstance.methods.GrowdropEndTime().call();
  },

  /*
  Growdrop contract's beneficiary call
  contractinstance => Growdrop contract instance
  return =>
  address of beneficiary (String)
  */
  BeneficiaryCall: async function(contractinstance) {
    return await contractinstance.methods.Beneficiary().call();
  },

  /*
  Growdrop contract's owner call
  contractinstance => Growdrop contract instance
  return =>
  address of owner (String)
  */
  OwnerCall: async function(contractinstance) {
    return await contractinstance.methods.Owner().call();
  },

  /*
  Growdrop contract's owner check call
  contractinstance => Growdrop contract instance
  account => address to check if it's owner
  return =>
  (Boolean true : owner, false : not owner)
  */
  CheckOwnerCall: async function(contractinstance, account) {
    return await contractinstance.methods.CheckOwner(account).call();
  },
  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  getExpectedRateCall: async function(contractinstance, src_token, dest_token, amount) {
    return await contractinstance.methods.getExpectedRate(src_token, dest_token, amount).call();
  },

  /*
  ERC20 token approve transaction
  contractinstance => ERC20 token contract instance
  to => address to approve (String)
  amount => amount to approve (Number)
  account => address approve to "to" address (String) 
  return => 
  (Boolean true : success, false : failed)
  */
  TokenApproveTx: async function(contractinstance, to, amount, account) {
    return await contractinstance.methods.approve(to, amount).send({from:account})
    .then(receipt => {
      return (receipt.status==true);
    }).catch(error => {
      return false;
    }); 
  },

  /*
  make new Growdrop Contract transaction (only owner can)
  contractinstance => GrowdropManager contract instance
  tokenaddress => dai contract address (set, String)
  ctokenaddress => compound cdai contract address (set, String)
  growdroptokenaddress => selling token address (String)
  beneficiaryaddress => beneficiary address (String)
  growdroptokenamount => selling token amount (Number)
  GrowdropPeriod => Growdrop contract's selling period (Number)
  ToUniswapGrowdropTokenAmount => selling token amount to add Uniswap (Number) 
  ToUniswapInterestRate => beneficiary's interest percentage to add Uniswap (1~99, Number)
  DonateId => Donate Label Id (Number)
  account => address calling (owner, String)
  return => 
  (Boolean true : success, false : failed)
  */
  NewGrowdropTx: async function(
    contractinstance, 
    tokenaddress, 
    ctokenaddress, 
    growdroptokenaddress, 
    beneficiaryaddress, 
    growdroptokenamount, 
    GrowdropPeriod,
    ToUniswapGrowdropTokenAmount,
    ToUniswapInterestRate,
    DonateId,
    account) {
    return await contractinstance.methods.newGrowdrop(
      tokenaddress,
      ctokenaddress,
      growdroptokenaddress,
      beneficiaryaddress,
      growdroptokenamount,
      GrowdropPeriod,
      ToUniswapGrowdropTokenAmount,
      ToUniswapInterestRate,
      DonateId
    ).send({from:account})
    .then(receipt => {
      return (receipt.status==true);
    }).catch(error => {
      return false;
    }); 
  },

  /*
  Start Growdrop Contract transaction (only beneficiary can)
  contractinstance => Growdrop contract instance
  account => address calling (beneficiary, String)
  return => 
  (Boolean true : success, false : failed)
  */
  StartGrowdropTx: async function(contractinstance, account) {
    return await contractinstance.methods.StartGrowdrop().send({from:account})
    .then(receipt => {
      return (receipt.status==true);
    }).catch(error => {
      return false;
    }); 
  },

  /*
  add investing amount
  contractinstance => Growdrop contract instance
  amount => amount to add investing (Number)
  account => address adding (String)
  return => 
  (Boolean true : success, false : failed)
  */
  MintTx: async function(contractinstance, amount, account) {
    await contractinstance.methods.Mint(amount).send({from:account})
    .then(receipt => {
      return (receipt.status==true);
    }).catch(error => {
      return false;
    }); 
  },

  /*
  subtract investing amount
  contractinstance => Growdrop contract instance
  amount => amount to subtract investing (Number)
  account => address subtracting (String)
  return => 
  (Boolean true : success, false : failed)
  */
  RedeemTx: async function(contractinstance, amount, account) {
    return await contractinstance.methods.Redeem(amount).send({from:account})
    .then(receipt => {
      return (receipt.status==true);
    }).catch(error => {
      return false;
    }); 
  },

  /*
  Withdraw interest (beneficiary)
  Withdraw invested amount and get selling token (investor)
  contractinstance => Growdrop contract instance
  ToUniswap => true : add to uniswap, false : not add to uniswap (only for beneficiary, investor doesn't care, Boolean)
  account => address calling (String)
  return => 
  (Boolean true : success, false : failed)
  */
  WithdrawTx: async function(contractinstance, ToUniswap, account) {
    return await contractinstance.methods.Withdraw(ToUniswap).send({from:account})
    .then(receipt => {
      return (receipt.status==true);
    }).catch(error => {
      return false;
    });
  },

  setElement_innerHTML: async function(element, text) {
    element.innerHTML = App.withDecimal(text);
  },

  setInvestorMintedResult: async function(events) {
    let InvestorMintedtemplaterow = $('#Growdrop_InvestorMintedevent_row');
    InvestorMintedtemplaterow.empty();
    let InvestorMintedtemplate = $('#Growdrop_InvestorMintedevent_template');
    for(let i = 0; i<events.length; i++) {
      if(parseInt(events[i].returnValues._ActionIdx)==0) {
        InvestorMintedtemplate.find('.InvestorMintedTimedisplay').text(new Date(parseInt(events[i].returnValues._ActionTime*1000)));
        InvestorMintedtemplate.find('.InvestorMintedAmountdisplay').text(App.withDecimal(events[i].returnValues._Amount));
      
        InvestorMintedtemplaterow.append(InvestorMintedtemplate.html());
      }
    }
  },

  setInvestorRedeemedResult: async function(events) {
    let InvestorRedeemedtemplaterow = $('#Growdrop_InvestorRedeemedevent_row');
    InvestorRedeemedtemplaterow.empty();
    let InvestorRedeemedtemplate = $('#Growdrop_InvestorRedeemedevent_template');
    for(let i = 0; i<events.length; i++) {
      if(parseInt(events[i].returnValues._ActionIdx)==1) {
        InvestorRedeemedtemplate.find('.InvestorRedeemedTimedisplay').text(new Date(parseInt(events[i].returnValues._ActionTime*1000)));
        InvestorRedeemedtemplate.find('.InvestorRedeemedAmountdisplay').text(App.withDecimal(events[i].returnValues._Amount));
        
        InvestorRedeemedtemplaterow.append(InvestorRedeemedtemplate.html());
      }
    }
  },

  getGrowdropActionPastEvents: async function(contractinstance, GrowdropAddress, Account) {
    /*
    filter : 
    _eventIdx, => event number (Number)
    _Growdrop, => growdrop contract address (String)
    _From => account address (String)
    */
    contractinstance.getPastEvents("GrowdropAction", {filter: {_Growdrop: GrowdropAddress, _From:Account},fromBlock: 0,toBlock: 'latest'}).then(function(events) {
      /*
      events[i].returnValues._eventIdx, (Number)
      events[i].returnValues._Growdrop, (String)
      events[i].returnValues._From, (String)
      events[i].returnValues._Amount, => 0 : Mint Amount, 1 : Redeem Amount, 2 : nothing(0), 3 : Growdrop Token Amount, 4 : nothing(0) (Number)
      events[i].returnValues._ActionTime, (Number unix timestamp)
      events[i].returnValues._ActionIdx, => 0 : Mint, 1 : Redeem, 2 : BeneficiaryWithdraw, 3 : InvestorWithdraw, 4 : UserJoinedGrowdrop , 5 : GrowdropStart , 6 : GrowdropEnded (Number)
      */
      App.setInvestorMintedResult(events);
      App.setInvestorRedeemedResult(events);
    });
  },

  newGrowdropContractPastEvents: async function(contractinstance, account) {
    /*
    filter : 
    _eventIdx, => event number (Number)
    _idx, => growdrop contract index (Number)
    _beneficiary => Growdrop contract beneficiary (String)
    */
    contractinstance.getPastEvents("NewGrowdropContract", {filter: {_beneficiary:account}, fromBlock: 0, toBlock: 'latest'}).then(function(events) {
      /*
      events[i].returnValues._eventIdx, (Number)
      events[i].returnValues._idx, (Number)
      events[i].returnValues._beneficiary, (String)
      events[i].returnValues._GrowdropAddress (String)
      */ 
    });
  },

  allPastEvents: async function(contractinstance) {
    /*
    filter: no filtering
    */
    contractinstance.getPastEvents("allEvents", {fromBlock: 0, toBlock: 'latest'}).then(function(events) {
      /*
      events[i].event => event name
      events[i].returnValues... => event results
      */
    });
  },

  refresh: async function() {
    const DAIbalance = await this.TokenBalanceOfCall(this.DAI, App.account);
    const KyberDAIbalance = await this.TokenBalanceOfCall(this.KyberDAI, App.account);
    const SimpleTokenbalance = await this.TokenBalanceOfCall(this.SimpleToken, App.account);

    const DAIAllowance = await App.TokenAllowanceCall(App.DAI, App.account, App.Growdrop._address);
    const KyberDAIAllowance = await App.TokenAllowanceCall(App.KyberDAI, App.account, App.Growdrop._address);    
    const SimpleTokenAllowance = await App.TokenAllowanceCall(
      App.SimpleToken, 
      App.account, 
      App.Growdrop._address
    );

    const expectedRate = await App.getExpectedRateCall(
      App.KyberNetworkProxy,
      App.KyberDAI._address, 
      App.KyberEthTokenAddress, 
      "1000000000000000000"
    );

    const GetUniswapLiquidityPoolRes =await App.GetUniswapLiquidityPoolCall(
      App.Tokenswap, 
      App.SimpleToken._address
    );

    const DAIbalanceElement = document.getElementsByClassName("DAIbalance")[0];
    this.setElement_innerHTML(DAIbalanceElement, DAIbalance);
    const KyberDAIbalanceElement = document.getElementsByClassName("KyberDAIbalance")[0];
    this.setElement_innerHTML(KyberDAIbalanceElement, KyberDAIbalance);
    const SimpleTokenbalanceElement = document.getElementsByClassName("SimpleTokenbalance")[0];
    this.setElement_innerHTML(SimpleTokenbalanceElement, SimpleTokenbalance);
    const DAIAllowanceElement = document.getElementsByClassName("DAIAllowance")[0];
    App.setElement_innerHTML(DAIAllowanceElement, DAIAllowance);
    const KyberDAIAllowanceElement = document.getElementsByClassName("KyberDAIAllowance")[0];
    App.setElement_innerHTML(KyberDAIAllowanceElement, KyberDAIAllowance);
    const SimpleTokenAllowanceElement = document.getElementsByClassName("SimpleTokenAllowance")[0];
    App.setElement_innerHTML(SimpleTokenAllowanceElement, SimpleTokenAllowance);

    const UniswapSimpleTokenEthPoolElement = document.getElementsByClassName("UniswapSimpleTokenEthPool")[0];
    App.setElement_innerHTML(UniswapSimpleTokenEthPoolElement, GetUniswapLiquidityPoolRes[0]);
    
    const UniswapSimpleTokenTokenPoolElement = document.getElementsByClassName("UniswapSimpleTokenTokenPool")[0];
    App.setElement_innerHTML(UniswapSimpleTokenTokenPoolElement, GetUniswapLiquidityPoolRes[1]);
    
    const DaiToEthElement = document.getElementsByClassName("KyberDaiToEth")[0];
    App.setElement_innerHTML(DaiToEthElement, expectedRate[0]);

    const GrowdropData_value = await App.GetGrowdropDataCall(App.GrowdropCall, App.Growdrop._address);

    if(GrowdropData_value[8]==false) {
      $(document).find('.GrowdropStatusdisplay').text("pending");
    } else if (GrowdropData_value[7]==false) {
      $(document).find('.GrowdropStatusdisplay').text("running");
    } else {
      $(document).find('.GrowdropStatusdisplay').text("ended");
    }

    $(document).find('.GrowdropTokendisplay').text(GrowdropData_value[0]);
    $(document).find('.Beneficiarydisplay').text(GrowdropData_value[1]);
    $(document).find('.GrowdropStartTimedisplay').text(new Date(parseInt(GrowdropData_value[3]*1000)));
    $(document).find('.GrowdropEndTimedisplay').text(new Date(parseInt(GrowdropData_value[4]*1000)));
    $(document).find('.GrowdropPerioddisplay').text(
      (parseInt(GrowdropData_value[4]*1000)-parseInt(GrowdropData_value[3]*1000))
    );
    $(document).find('.GrowdropAmountdisplay').text(App.withDecimal(GrowdropData_value[2]));

    const GrowdropOver_value = GrowdropData_value[7];
    if(GrowdropOver_value && App.withDecimal(GrowdropData_value[5])>0) {
      const UserData_value = await App.GetUserDataCall(App.GrowdropCall, App.Growdrop._address, App.account);
      $(document).find('.TotalMintedAmountdisplay').text(App.withDecimal(GrowdropData_value[6]));
      $(document).find('.TotalInterestdisplay').text(
        App.withDecimal(
          String(
            App.toBigInt(GrowdropData_value[5])
            .subtract(App.toBigInt(GrowdropData_value[6]))
          )
        )
      );

      const CurrentDaiToEthElement = document.getElementsByClassName("CurrentDaiToEth")[0];
      App.setElement_innerHTML(CurrentDaiToEthElement, 
        App.toBigInt(expectedRate[0])
        .multiply(
          App.toBigInt(GrowdropData_value[5])
          .subtract(App.toBigInt(GrowdropData_value[6]))
          )
        .divide(App.toBigInt(1000000000000000000)));

      $(document).find('.TotalBalancedisplay').text(App.withDecimal(GrowdropData_value[5]));

      $(document).find('.TotalPerAddressdisplay').text(App.withDecimal(UserData_value[1]));
      $(document).find('.InvestAmountPerAddressdisplay').text(App.withDecimal(UserData_value[0]));
      $(document).find('.InterestPerAddressdisplay').text(App.withDecimal(UserData_value[2]));
      $(document).find('.InterestRatedisplay').text(App.withDecimal(UserData_value[3]));
      $(document).find('.TokenByInterestdisplay').text(App.withDecimal(UserData_value[4]));
    } else {
      $(document).find('.TotalBalancedisplay').text(App.withDecimal(GrowdropData_value[5]));
      $(document).find('.TotalMintedAmountdisplay').text(App.withDecimal(GrowdropData_value[6]));

      if(App.toBigInt(GrowdropData_value[5])<=App.toBigInt(GrowdropData_value[6])) {
        $(document).find('.TotalInterestdisplay').text("wait for accrueinterest transaction");
        $(document).find('.TotalPerAddressdisplay').text("wait for accrueinterest transaction");
        $(document).find('.InvestAmountPerAddressdisplay').text("wait for accrueinterest transaction");
        $(document).find('.InterestPerAddressdisplay').text("wait for accrueinterest transaction");
        $(document).find('.InterestRatedisplay').text("wait for accrueinterest transaction");
        $(document).find('.TokenByInterestdisplay').text("wait for accrueinterest transaction");
      } else {
        const TotalPerAddressres = await App.TotalPerAddressCall(App.Growdrop, App.account);
        $(document).find('.TotalPerAddressdisplay').text(App.withDecimal(TotalPerAddressres));
        
        const InvestAmountPerAddressres = await App.InvestAmountPerAddressCall(App.Growdrop, App.account);
        $(document).find('.InvestAmountPerAddressdisplay').text(App.withDecimal(InvestAmountPerAddressres));

        if(App.toBigInt(TotalPerAddressres)<=App.toBigInt(InvestAmountPerAddressres)) {
          $(document).find('.TotalInterestdisplay').text("wait for accrueinterest transaction");
          $(document).find('.InterestPerAddressdisplay').text("wait for accrueinterest transaction");
          $(document).find('.InterestRatedisplay').text("wait for accrueinterest transaction");
          $(document).find('.TokenByInterestdisplay').text("wait for accrueinterest transaction");
        } else {
          const UserData_value = await App.GetUserDataCall(
            App.GrowdropCall, 
            App.Growdrop._address, 
            App.account
          );
          $(document).find('.TotalInterestdisplay').text(
            App.withDecimal(
              String(
                App.toBigInt(GrowdropData_value[5])
                .subtract(App.toBigInt(GrowdropData_value[6]))
              )
            )
          );
          const CurrentDaiToEthElement = document.getElementsByClassName("CurrentDaiToEth")[0];
          App.setElement_innerHTML(CurrentDaiToEthElement, 
            App.toBigInt(expectedRate[0])
            .multiply(
              App.toBigInt(GrowdropData_value[5])
              .subtract(App.toBigInt(GrowdropData_value[6]))
              )
            .divide(App.toBigInt(1000000000000000000)));
          $(document).find('.InterestPerAddressdisplay').text(App.withDecimal(UserData_value[2]));
          $(document).find('.InterestRatedisplay').text(App.withDecimal(UserData_value[3]));
          $(document).find('.TokenByInterestdisplay').text(App.withDecimal(UserData_value[4]));
        }
      }
    }

  },

  refreshGrowdrop: async function() {
    const getGrowdropListLengthres = await App.GetGrowdropListLengthCall(App.GrowdropManager);
    if(App.toBigInt(getGrowdropListLengthres)==0) {
      App.setStatus("there is no growdrop contract yet");
    } else {
      const getGrowdropres = await App.GetGrowdropCall(
        App.GrowdropManager, 
        String(App.toBigInt(getGrowdropListLengthres)-App.toBigInt(1))
      );

      App.Growdrop = this.contractInit(GrowdropArtifact.abi, getGrowdropres);
    }
  },

  Mint: async function() {
    var MintAmount = parseInt(document.getElementById("Mintinput").value);
    App.setStatus("Initiating Mint transaction... (please wait)");
    const Mint_res = await App.MintTx(App.Growdrop, String(MintAmount), App.account);
    App.setStatus(Mint_res);
  },

  Redeem: async function() {
    var RedeemAmount = parseInt(document.getElementById("Redeeminput").value);
    App.setStatus("Initiating Redeem transaction... (please wait)");
    const Redeem_res = await App.RedeemTx(App.Growdrop, String(RedeemAmount), App.account);
    App.setStatus(Redeem_res);
  },

  Withdraw: async function() {
    const add_to_uniswap = parseInt(document.getElementById("AddToUniswap").value);
    App.setStatus("Initiating Withdraw transaction... (please wait)");
    if(add_to_uniswap==1) {
      const Withdraw_res = await App.WithdrawTx(App.Growdrop, true, App.account);
      App.setStatus(Withdraw_res);
    } else {
      const Withdraw_res = await App.WithdrawTx(App.Growdrop, false, App.account);
      App.setStatus(Withdraw_res);
    }
  },

  approveDAI: async function() {
    const amount = parseInt(document.getElementById("DAIamount").value);

    App.setStatus("Initiating approveDAI transaction... (please wait)");
    const approve_res = await App.TokenApproveTx(
      App.DAI, 
      App.Growdrop._address, 
      String(amount), 
      App.account
    );
    App.setStatus(approve_res);
  },

  approveSimpleToken: async function() {
    const amount = parseInt(document.getElementById("SimpleTokenamount").value);

    App.setStatus("Initiating approveSimpleToken transaction... (please wait)");
    const approve_res = await App.TokenApproveTx(
      App.SimpleToken, 
      App.Growdrop._address, 
      String(amount), 
      App.account
    );
    App.setStatus(approve_res);
  },

  NewGrowdrop: async function() {
    const amount = parseInt(document.getElementById("NewGrowdropamount").value);
    const beneficiary = document.getElementById("NewGrowdropbeneficiary").value;
    const period = document.getElementById("GrowdropPeriod").value;
    const ToUniswapGrowdropTokenAmount = document.getElementById("ToUniswapGrowdropTokenAmount").value;
    const ToUniswapInterestRate = document.getElementById("ToUniswapInterestRate").value;
    const donateid = document.getElementById("NewGrowdropDonateId").value;
    var growdroptoken = App.SimpleTokenAddress;
    if(donateid!="0") {
      growdroptoken = App.DonateToken._address;
    }
    App.setStatus("Initiating NewGrowdrop transaction... (please wait)");
    const newGrowdrop_res = await App.NewGrowdropTx(
      App.GrowdropManager,
      App.DAI._address,
      App.cDAIAddress,
      growdroptoken,
      beneficiary,
      String(amount),
      period,
      String(ToUniswapGrowdropTokenAmount),
      ToUniswapInterestRate,
      donateid,
      App.account
      );

    await App.refreshGrowdrop();
    await App.refresh();
    App.setStatus(newGrowdrop_res);
  },

  StartGrowdrop: async function() {
    App.setStatus("Initiating StartGrowdrop transaction... (please wait)");
    const StartGrowdrop_res = await App.StartGrowdropTx(App.Growdrop, App.account);
    App.setStatus(StartGrowdrop_res);
  },

  setStatus: function(message) {
    const status = document.getElementById("status");
    status.innerHTML = message;
  },  

  bindEvents: function() {
    $(document).on('change', '#IpfsFileAdd', App.AddFileToIpfs);
  },  

  AddFileToIpfs: async function(event) {
    event.preventDefault();
    var ipfsId;
    App.setStatus("ipfs saving...");
    App.ipfs.add([...event.target.files], { progress: (prog) => console.log(`received: ${prog}`) })
    .then(function(response) {
      console.log(response)
      App.setStatus("ipfs pinning...");
      ipfsId = response[0].hash
      return App.ipfs.pin.add(ipfsId)
    }).then(function(response) {
      App.CheckDonateIdAndSet(ipfsId);
      console.log("https://ipfs.io/ipfs/"+ipfsId);
    }).catch((err) => {
      console.error(err)
    });
  },

  CheckDonateIdAndSet: async function(ipfshash) {
    const { digest, hashFunction, size } = App.getBytes32FromMultihash(ipfshash);
    const MultihashToDonateIdRes = await App.MultihashToDonateIdCall(
      App.DonateToken, 
      digest, 
      hashFunction, 
      size
    );
    if(MultihashToDonateIdRes=="0") {
      const SetMultihashRes = await App.SetMultihashTx(
        App.DonateToken, 
        digest, 
        hashFunction, 
        size, 
        App.account
      );
      App.setStatus(SetMultihashRes);
    } else {
      App.setStatus(MultihashToDonateIdRes);
    }
  },

  getBytes32FromMultihash: function(multihash) {
    const decoded = bs58.decode(multihash);
  
    return {
      digest: `0x${decoded.slice(2).toString('hex')}`,
      hashFunction: decoded[0],
      size: decoded[1],
    };
  },

  getMultihashFromBytes32: function(multihash) {
    const { digest, hashFunction, size } = multihash;
    if (size === 0) return null;
  
    const hashBytes = Buffer.from(digest.slice(2), 'hex');
  
    const multihashBytes = new (hashBytes.constructor)(2 + hashBytes.length);
    multihashBytes[0] = hashFunction;
    multihashBytes[1] = size;
    multihashBytes.set(hashBytes, 2);
  
    return bs58.encode(multihashBytes);
  },

  KyberswapEthToToken: async function() {
    const amount = document.getElementById("KyberswapEthToTokenAmount").value;
    const KyberswapEthToTokenRes = await this.KyberswapEthToTokenTx(
      App.Tokenswap, 
      App.KyberDAIAddress, 
      amount, 
      App.account
    );
    this.setStatus(KyberswapEthToTokenRes);
  },

  UniswapToken: async function() {
    const amount = document.getElementById("UniswapTokenAmount").value;
    const UniswapTokenRes = await this.UniswapTokenTx(
      App.Tokenswap, 
      App.KyberDAIAddress,
      App.DAIAddress,
      amount,
      App.account
    );
    this.setStatus(UniswapTokenRes);
  },

  GetExpectedAmount: async function() {
    const ethordai = document.getElementById("GetExpectedAmountEthOrDai").value;
    const amount = document.getElementById("GetExpectedAmountAmount").value;
    var ethordaibool=true;
    if(ethordai=="eth") {
      ethordaibool=false;
    }
    const GetExpectedAmountRes = await this.GetExpectedAmountCall(
      App.Tokenswap, 
      ethordaibool, 
      App.KyberDAIAddress, 
      amount
    );
    this.setStatus(GetExpectedAmountRes);
  },

  DonateInfoToTokenAmount: async function() {
    const beneficiary = document.getElementById("DonateInfoToTokenAmountTo").value;
    const donateid = document.getElementById("DonateInfoToTokenAmountDonateId").value;
    const DonateInfoToTokenAmountRes = await this.DonateInfoToTokenAmountCall(
      App.DonateToken, 
      App.account, 
      beneficiary, 
      App.DAIAddress,
      donateid
    );
    this.setStatus(DonateInfoToTokenAmountRes);
  },

  DonateIdOwner: async function() {
    const donateid = document.getElementById("DonateIdOwnerDonateId").value;
    const DonateIdOwnerRes = await this.DonateIdOwnerCall(App.DonateToken,donateid);
    this.setStatus(DonateIdOwnerRes);
  },

  GetMultihash: async function() {
    const donateid = document.getElementById("GetMultihashDonateId").value;
    const GetMultihashRes = await this.GetMultihashCall(App.DonateToken, donateid);
    const toBytes32 = this.parseContractResponse(GetMultihashRes);
    const toIpfshash = this.getMultihashFromBytes32(toBytes32);
    this.setStatus(toIpfshash);
  },

  MultihashToDonateId: async function() {
    const ipfshash = document.getElementById("MultihashToDonateIdIpfshash").value;
    const { digest, hashFunction, size } = this.getBytes32FromMultihash(ipfshash);
    const MultihashToDonateIdRes = await this.MultihashToDonateIdCall(
      App.DonateToken, 
      digest,
      hashFunction,
      size
    );
    this.setStatus(MultihashToDonateIdRes);
  },
  
  parseContractResponse: function(response) {
    return {
      digest: response[0],
      hashFunction: response[1],
      size: response[2],
    };
  },
  
};

window.App = App;

window.addEventListener("load", function() {
  App.bindEvents();
});
