import Web3 from "web3";
import GrowdropArtifact from "../../build/contracts/Growdrop.json";
import GrowdropKovanArtifact from "../../build/contracts/Growdrop_kovan.json";
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
  DonateToken: null,
  Tokenswap: null,
  GrowdropCall: null,
  KyberNetworkProxy: null,
  latestGrowdrop: null,
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

  withCTokenDecimal: function(number) {
    return String(App.toBigInt(number).divide(new bigdecimal.BigDecimal("100000000")));
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
      this.DAIAddress="0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359";
      this.KyberDAIAddress="0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359";
      this.KyberNetworkProxyAddress="0x818E6FECD516Ecc3849DAf6845e3EC868087B755";
      //SimpleTokenAddress="0x53cc0b020c7c8bbb983d0537507d2c850a22fa4c";
      this.KyberEthTokenAddress="0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
      this.cDAIAddress="0xf5dce57282a584d2746faf1593d3121fcac444dc";
    }
    const deployedNetwork_growdrop = GrowdropArtifact.networks[networkId];
    const deployedNetwork_donatetoken = DonateToken.networks[networkId];
    const deployedNetwork_tokenswap = Tokenswap.networks[networkId];
    const deployedNetwork_growdropcall = GrowdropCall.networks[networkId];

    if(networkId==42) {
      const deployedNetwork_growdrop_kovan = GrowdropKovanArtifact.networks[networkId];
      this.Growdrop = this.contractInit(GrowdropKovanArtifact.abi, deployedNetwork_growdrop_kovan.address);
      this.SimpleToken = this.contractInit(SimpleTokenABI.abi, this.SimpleTokenAddress);
    } else if (networkId==1) {
      this.Growdrop = this.contractInit(GrowdropArtifact.abi, deployedNetwork_growdrop.address);
    }
    this.DonateToken = this.contractInit(DonateToken.abi, deployedNetwork_donatetoken.address);
    this.Tokenswap = this.contractInit(Tokenswap.abi, deployedNetwork_tokenswap.address);
    this.GrowdropCall = this.contractInit(GrowdropCall.abi, deployedNetwork_growdropcall.address);
    
    this.DAI = this.contractInit(EIP20Interface.abi, this.DAIAddress);
    this.KyberDAI = this.contractInit(EIP20Interface.abi, this.KyberDAIAddress);
    this.KyberNetworkProxy = this.contractInit(KyberNetworkProxy.abi, this.KyberNetworkProxyAddress);
    this.ipfs = ipfsClient('ipfs.infura.io', '5001', {protocol:'https'})

    this.account = await this.getProviderCurrentAccount();
    await this.refresh();
  },

  KyberswapEthToTokenTx: async function(contractinstance, token, amount, account) {
    return contractinstance.methods.kyberswapEthToToken(token).send({from:account, value:amount})
    .on('transactionHash', function(hash) {
      console.log("transaction hash : "+hash);
    }).on('confirmation', function(confirmationNumber) {
      if(confirmationNumber==6) {
        console.log("confirmed+ "+confirmationNumber);
      }
    }).on('receipt', function(receipt) {
      return receipt;
    }).on('error', function(error) {
      return error;
    });
  },

  UniswapTokenTx: async function(contractinstance, fromtoken, totoken, amount, account) {
    return contractinstance.methods.uniswapToken(fromtoken, totoken, amount).send({from:account})
    .on('transactionHash', function(hash) {
      console.log("transaction hash : "+hash);
    }).on('confirmation', function(confirmationNumber) {
      if(confirmationNumber==6) {
        console.log("confirmed+ "+confirmationNumber);
      }
    }).on('receipt', function(receipt) {
      return receipt;
    }).on('error', function(error) {
      return error;
    });
  },

  GetGrowdropCountCall: async function(contractinstance) {
    return await contractinstance.methods.GrowdropCount().call();
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
    return contractinstance.methods.setMultihash(hash,hashfunction,size).send({from:account})
    .on('transactionHash', function(hash) {
      console.log("transaction hash : "+hash);
    }).on('confirmation', function(confirmationNumber) {
      if(confirmationNumber==6) {
        console.log("confirmed+ "+confirmationNumber);
      }
    }).on('receipt', function(receipt) {
      return receipt;
    }).on('error', function(error) {
      return error;
    });
  },

  /*

  */
  getDonateEvent: function(receipt) {
    var ret = {
      event_idx: receipt.events.DonateEvent.returnValues.event_idx,
      from: receipt.events.DonateEvent.returnValues.from,
      donate_id: receipt.events.DonateEvent.returnValues.donate_id,
      hash: receipt.events.DonateEvent.returnValues.hash,
      hash_function: receipt.events.DonateEvent.returnValues.hash_function,
      size: receipt.events.DonateEvent.returnValues.size,
    };
    return ret;
  },

  getDonateActionEvent: function(receipt) {
    var ret = {
      event_idx: receipt.events.DonateAction.returnValues.event_idx,
      from: receipt.events.DonateAction.returnValues.from,
      to: receipt.events.DonateAction.returnValues.to,
      supporter: receipt.events.DonateAction.returnValues.supporter,
      beneficiary: receipt.events.DonateAction.returnValues.beneficiary,
      token_address: receipt.events.DonateAction.returnValues.token_address,
      donate_id: receipt.events.DonateAction.returnValues.donate_id,
      token_id: receipt.events.DonateAction.returnValues.token_id,
      amount: receipt.events.DonateAction.returnValues.amount,
      action_idx: receipt.events.DonateAction.returnValues.action_idx,
    }
    return ret;
  },

  /*

  */
  getGrowdropEvent: function(receipt) {
    if(receipt.events.GrowdropAction.length==2) {
      var ret = [{
        event_idx: receipt.events.GrowdropAction[0].returnValues.event_idx,
        growdrop_count: receipt.events.GrowdropAction[0].returnValues.growdrop_count,
        action_idx: receipt.events.GrowdropAction[0].returnValues.action_idx,
        from: receipt.events.GrowdropAction[0].returnValues.from,
        amount1: receipt.events.GrowdropAction[0].returnValues.amount1,
        amount2: receipt.events.GrowdropAction[0].returnValues.amount2,
      },
      {
        event_idx: receipt.events.GrowdropAction[1].returnValues.event_idx,
        growdrop_count: receipt.events.GrowdropAction[1].returnValues.growdrop_count,
        action_idx: receipt.events.GrowdropAction[1].returnValues.action_idx,
        from: receipt.events.GrowdropAction[1].returnValues.from,
        amount1: receipt.events.GrowdropAction[1].returnValues.amount1,
        amount2: receipt.events.GrowdropAction[1].returnValues.amount2,
      }]
      return ret;
    }
    var ret = {
      event_idx: receipt.events.GrowdropAction.returnValues.event_idx,
      growdrop_count: receipt.events.GrowdropAction.returnValues.growdrop_count,
      action_idx: receipt.events.GrowdropAction.returnValues.action_idx,
      from: receipt.events.GrowdropAction.returnValues.from,
      amount1: receipt.events.GrowdropAction.returnValues.amount1,
      amount2: receipt.events.GrowdropAction.returnValues.amount2
    };
    return ret;
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
  contractinstance => Growdrop contract instance
  GrowdropCount => Growdrop contract index
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
  GetGrowdropDataCall: async function(contractinstance, GrowdropCount, account) {
    return await contractinstance.methods.getGrowdropData(GrowdropCount).call({from:account});
  },

  GetGrowdropStateDataCall: async function(contractinstance, GrowdropCount, account) {
    return await contractinstance.methods.getGrowdropStateData(GrowdropCount).call({from:account});
  },

  GetGrowdropAmountDataCall: async function(contractinstance, GrowdropCount, account) {
    return await contractinstance.methods.getGrowdropAmountData(GrowdropCount).call({from:account});
  },

  /*
  address's invested amount call
  contractinstance => Growdrop contract instance
  GrowdropCount => Growdrop index
  account => address to get data (String)
  return =>
  user's invested amount to Growdrop contract (Number)
  */
  InvestAmountPerAddressCall: async function(contractinstance, GrowdropCount, account) {
    return await contractinstance.methods.InvestAmountPerAddress(GrowdropCount, account).call();
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
  GrowdropCount => Growdrop index
  return =>
  user count to Growdrop contract (Number)
  */
  TotalUserCountCall: async function(contractinstance, GrowdropCount) {
    return await contractinstance.methods.TotalUserCount(GrowdropCount).call();
  },

  /*
  Growdrop contract's total invested amount call
  contractinstance => Growdrop contract instance
  GrowdropCount => Growdrop index
  return =>
  total invested amount to Growdrop contract (Number)
  */
  TotalMintedAmountCall: async function(contractinstance, GrowdropCount) {
    return await contractinstance.methods.TotalMintedAmount(GrowdropCount).call();
  },

  /*
  Growdrop contract's selling token contract address call
  contractinstance => Growdrop contract instance
  GrowdropCount => Growdrop index
  return =>
  address of Growdrop token contract (String)
  */
  GrowdropTokenCall: async function(contractinstance, GrowdropCount) {
    return await contractinstance.methods.GrowdropToken(GrowdropCount).call();
  },

  /*
  Growdrop contract's end time call
  contractinstance => Growdrop contract instance
  GrowdropCount => Growdrop index
  return => 
  Growdrop end time (Number unix timestamp)
  */
  GrowdropEndTimeCall: async function(contractinstance, GrowdropCount) {
    return await contractinstance.methods.GrowdropEndTime(GrowdropCount).call();
  },

  /*
  Growdrop contract's beneficiary call
  contractinstance => Growdrop contract instance
  GrowdropCount => Growdrop index
  return =>
  address of beneficiary (String)
  */
  BeneficiaryCall: async function(contractinstance, GrowdropCount) {
    return await contractinstance.methods.Beneficiary(GrowdropCount).call();
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
    return contractinstance.methods.approve(to, amount).send({from:account})
    .on('transactionHash', function(hash) {
      console.log("transaction hash : "+hash);
    }).on('confirmation', function(confirmationNumber) {
      if(confirmationNumber==6) {
        console.log("confirmed+ "+confirmationNumber);
      }
    }).on('receipt', function(receipt) {
      return receipt;
    }).on('error', function(error) {
      return error;
    });
  },

  /*
    ERC20, ERC721 token transferFrom transaction
    contractinstance => ERC20, ERC721 token contract instance
    from => address sending token (String)
    to => address receiving token (String)
    amount => amount to transfer (Number)
    account => address calling transfer (String)

    return =>
    (Boolean true : success, false : failed)
    */
   TokenTransferFromTx: async function (contractinstance, from, to, amount, account) {
    return await contractinstance.methods.transferFrom(from, to, amount).send({from: account})
    .on('transactionHash', function(hash) {
      ////console.log("transaction hash : "+hash);
    }).on('confirmation', function(confirmationNumber) {
      if(confirmationNumber==6) {
        //console.log(confirmed+" "+confirmationNumber);
      }
    }).on('receipt', function(receipt) {
      return receipt;
    }).on('error', function(error) {
      return error;
    });
  },

  /*
  make new Growdrop Contract transaction (only owner can)
  contractinstance => Growdrop contract instance
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
    return contractinstance.methods.newGrowdrop(
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
    .on('transactionHash', function(hash) {
      console.log("transaction hash : "+hash);
    }).on('confirmation', function(confirmationNumber) {
      if(confirmationNumber==6) {
        console.log("confirmed+ "+confirmationNumber);
      }
    }).on('receipt', function(receipt) {
      return receipt;
    }).on('error', function(error) {
      return error;
    });
  },

  /*
  Start Growdrop Contract transaction (only beneficiary can)
  contractinstance => Growdrop contract instance
  GrowdropCount => Growdrop index
  account => address calling (beneficiary, String)
  return => 
  (Boolean true : success, false : failed)
  */
  StartGrowdropTx: async function(contractinstance, GrowdropCount, account) {
    return contractinstance.methods.StartGrowdrop(GrowdropCount).send({from:account})
    .on('transactionHash', function(hash) {
      console.log("transaction hash : "+hash);
    }).on('confirmation', function(confirmationNumber) {
      if(confirmationNumber==6) {
        console.log("confirmed+ "+confirmationNumber);
      }
    }).on('receipt', function(receipt) {
      return receipt;
    }).on('error', function(error) {
      return error;
    });
  },

  /*
  add investing amount
  contractinstance => Growdrop contract instance
  GrowdropCount => Growdrop index
  amount => amount to add investing (Number)
  account => address adding (String)
  return => 
  (Boolean true : success, false : failed)
  */
  MintTx: async function(contractinstance, GrowdropCount, amount, account) {
    return contractinstance.methods.Mint(GrowdropCount, amount).send({from:account})
    .on('transactionHash', function(hash) {
      console.log("transaction hash : "+hash);
    }).on('confirmation', function(confirmationNumber) {
      if(confirmationNumber==6) {
        console.log("confirmed+ "+confirmationNumber);
      }
    }).on('receipt', function(receipt) {
      return receipt;
    }).on('error', function(error) {
      return error;
    });
  },

  /*
  subtract investing amount
  contractinstance => Growdrop contract instance
  GrowdropCount => Growdrop index
  amount => amount to subtract investing (Number)
  account => address subtracting (String)
  return => 
  (Boolean true : success, false : failed)
  */
  RedeemTx: async function(contractinstance, GrowdropCount, amount, account) {
    return contractinstance.methods.Redeem(GrowdropCount, amount).send({from:account})
    .on('transactionHash', function(hash) {
      console.log("transaction hash : "+hash);
    }).on('confirmation', function(confirmationNumber) {
      if(confirmationNumber==6) {
        console.log("confirmed+ "+confirmationNumber);
      }
    }).on('receipt', function(receipt) {
      return receipt;
    }).on('error', function(error) {
      return error;
    });
  },

  /*
  Withdraw interest (beneficiary)
  Withdraw invested amount and get selling token (investor)
  contractinstance => Growdrop contract instance
  GrowdropCount => Growdrop index
  ToUniswap => true : add to uniswap, false : not add to uniswap (only for beneficiary, investor doesn't care, Boolean)
  account => address calling (String)
  return => 
  (Boolean true : success, false : failed)
  */
  WithdrawTx: async function(contractinstance, GrowdropCount, ToUniswap, account) {
    return contractinstance.methods.Withdraw(GrowdropCount, ToUniswap).send({from:account})
    .on('transactionHash', function(hash) {
      console.log("transaction hash : "+hash);
    }).on('confirmation', function(confirmationNumber) {
      if(confirmationNumber==6) {
        console.log("confirmed+ "+confirmationNumber);
      }
    }).on('receipt', function(receipt) {
      return receipt;
    }).on('error', function(error) {
      return error;
    });
  },

  setElement_innerHTML: async function(element, text) {
    element.innerHTML = App.withDecimal(text);
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
      console.log(events);
    });
  },

  refresh: async function() {
    this.latestGrowdrop = await this.GetGrowdropCountCall(this.Growdrop);
    const DAIbalance = await this.TokenBalanceOfCall(this.DAI, App.account);
    const KyberDAIbalance = await this.TokenBalanceOfCall(this.KyberDAI, App.account);
    if(this.SimpleToken!=null) {
      const SimpleTokenbalance = await this.TokenBalanceOfCall(this.SimpleToken, App.account);

      const GetUniswapLiquidityPoolRes =await App.GetUniswapLiquidityPoolCall(
        App.Tokenswap, 
        App.SimpleToken._address
      );

      const SimpleTokenbalanceElement = document.getElementsByClassName("SimpleTokenbalance")[0];
      this.setElement_innerHTML(SimpleTokenbalanceElement, SimpleTokenbalance);

      const UniswapSimpleTokenEthPoolElement = document.getElementsByClassName("UniswapSimpleTokenEthPool")[0];
      App.setElement_innerHTML(UniswapSimpleTokenEthPoolElement, GetUniswapLiquidityPoolRes[0]);
      
      const UniswapSimpleTokenTokenPoolElement = document.getElementsByClassName("UniswapSimpleTokenTokenPool")[0];
      App.setElement_innerHTML(UniswapSimpleTokenTokenPoolElement, GetUniswapLiquidityPoolRes[1]);
    }

    const DAIbalanceElement = document.getElementsByClassName("DAIbalance")[0];
    this.setElement_innerHTML(DAIbalanceElement, DAIbalance);
    const KyberDAIbalanceElement = document.getElementsByClassName("KyberDAIbalance")[0];
    this.setElement_innerHTML(KyberDAIbalanceElement, KyberDAIbalance);

    const GrowdropData_value = await App.GetGrowdropDataCall(App.GrowdropCall, App.latestGrowdrop, App.account);
    const GrowdropStateData_value = await App.GetGrowdropStateDataCall(App.GrowdropCall, App.latestGrowdrop, App.account);
    const GrowdropAmountData_value = await App.GetGrowdropAmountDataCall(App.GrowdropCall, App.latestGrowdrop, App.account);

    if(GrowdropStateData_value[2]==false) {
      $(document).find('.GrowdropStatusdisplay').text("pending");
    } else if (GrowdropStateData_value[3]==false) {
      $(document).find('.GrowdropStatusdisplay').text("running");
    } else {
      $(document).find('.GrowdropStatusdisplay').text("ended");
    }

    $(document).find('.GrowdropTokendisplay').text(GrowdropData_value[0]);
    $(document).find('.Beneficiarydisplay').text(GrowdropData_value[1]);
    $(document).find('.GrowdropStartTimedisplay').text(new Date(parseInt(GrowdropStateData_value[0]*1000)));
    $(document).find('.GrowdropEndTimedisplay').text(new Date(parseInt(GrowdropStateData_value[1]*1000)));
    $(document).find('.GrowdropAmountdisplay').text(App.withDecimal(GrowdropData_value[2]));

    $(document).find('.TotalBalancedisplay').text(App.withCTokenDecimal(GrowdropAmountData_value[0]));
    $(document).find('.TotalMintedAmountdisplay').text(App.withDecimal(GrowdropAmountData_value[1]));
    $(document).find('.TotalPerAddressdisplay').text(App.withCTokenDecimal(GrowdropAmountData_value[2]));
    $(document).find('.InvestAmountPerAddressdisplay').text(App.withDecimal(GrowdropAmountData_value[3]));
  },

  Mint: async function() {
    var MintAmount = parseInt(document.getElementById("Mintinput").value);
    const Mint_res = await App.MintTx(App.Growdrop, App.latestGrowdrop, String(MintAmount), App.account);
    if(Mint_res.status) {
      var GrowdropEventRes = App.getGrowdropEvent(Mint_res);
      console.log(GrowdropEventRes);
    }
  },

  Redeem: async function() {
    var RedeemAmount = parseInt(document.getElementById("Redeeminput").value);
    const Redeem_res = await App.RedeemTx(App.Growdrop, App.latestGrowdrop, String(RedeemAmount), App.account);
    if(Redeem_res.status) {
      var GrowdropEventRes = App.getGrowdropEvent(Redeem_res);
      console.log(GrowdropEventRes);
    }
  },

  Withdraw: async function() {
    const add_to_uniswap = parseInt(document.getElementById("AddToUniswap").value);
    var touniswap=false;
    if(add_to_uniswap==1) {
        touniswap=true;
    }
    const Withdraw_res = await App.WithdrawTx(App.Growdrop, App.latestGrowdrop, touniswap, App.account);
    if(Withdraw_res.status) {
      var GrowdropEventRes = App.getGrowdropEvent(Withdraw_res);
      console.log(GrowdropEventRes);
    }
  },

  approveDAI: async function() {
    const approve_res = await App.TokenApproveTx(
      App.DAI, 
      App.Growdrop._address, 
      String("115792089237316195423570985008687907853269984665640564039457584007913129639935"), 
      App.account
    );
    if(approve_res.status) {
      console.log("DAI approved");
    }
  },

  approveSimpleToken: async function() {
    App.setStatus("Initiating approveSimpleToken transaction... (please wait)");
    const approve_res = await App.TokenApproveTx(
      App.SimpleToken, 
      App.Growdrop._address, 
      String("115792089237316195423570985008687907853269984665640564039457584007913129639935"), 
      App.account
    );
    if(approve_res.status) {
      console.log("SimpleToken approved");
    }
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
      App.Growdrop,
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

    await App.refresh();
    console.log(newGrowdrop_res);
  },

  StartGrowdrop: async function() {
    App.setStatus("Initiating StartGrowdrop transaction... (please wait)");
    const StartGrowdrop_res = await App.StartGrowdropTx(App.Growdrop, App.latestGrowdrop, App.account);
    if(StartGrowdrop_res.status) {
      var GrowdropEventRes = App.getGrowdropEvent(StartGrowdrop_res);
      console.log(GrowdropEventRes);
    }
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
    //App.setStatus("ipfs saving...");
    //console.log("ipfs saving");
    const response = await App.ipfs.add([...event.target.files])
    ipfsId=response[0].hash;
    //console.log(ipfsId);
    await App.ipfs.pin.add(ipfsId);
    //console.log("https://ipfs.io/ipfs/"+ipfsId);
    const donateId = await App.CheckDonateIdAndSet(ipfsId);
    return donateId;
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
      if(SetMultihashRes.status) {
        var DonateEventRes = App.getDonateEvent(SetMultihashRes);
        console.log(DonateEventRes);
      }
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
    console.log(KyberswapEthToTokenRes);
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
    console.log(UniswapTokenRes);
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