
pragma solidity ^0.5.11;

import "./ERC721.sol";
import "./Growdrop.sol";

contract DonateToken is ERC721 {
    mapping(address => bool) public CheckOwner;
    Growdrop growdrop;
    
    struct Multihash {
        bytes32 hash;
        uint8 hash_function;
        uint8 size;
    }
    
    struct DonateInfo {
        address supporter;
        address beneficiary;
        address tokenAddress;
        uint256 tokenAmount;
        uint256 donateId;
    }
    
    mapping(
        address => mapping(
            address => mapping(
                address => mapping(
                    uint256 => uint256)))) public DonateInfoToTokenAmount;
                    
    mapping(uint256 => DonateInfo) private TokenIdToDonateInfo;
    mapping(uint256 => Multihash) private DonateIdToMultihash;
    mapping(uint256 => address) public DonateIdOwner;
    
    mapping(
        bytes32 => mapping(
            uint8 => mapping (
                uint8 => uint256))) public MultihashToDonateId;
    
    event DonateEvent(
        uint256 indexed _eventIdx,
        address indexed _from,
        uint256 indexed _donateId,
        bytes32 _hash,
        uint8 _hash_function,
        uint8 _size
    );
    
    constructor (address payable _Growdrop) public {
        CheckOwner[msg.sender] = true;
        growdrop = Growdrop(_Growdrop);
    }

    function addOwner(address _Owner) public {
        require(CheckOwner[msg.sender]);
        CheckOwner[_Owner] = !CheckOwner[_Owner];
    }
    
    function setGrowdropManager(address payable _Growdrop) public {
        require(CheckOwner[msg.sender]);
        growdrop = Growdrop(_Growdrop);
    }
    
    function setMultihash(bytes32 _hash, uint8 hash_function, uint8 size) public {
        uint256 donateId = uint256(keccak256(abi.encode(_hash, hash_function, size)));
        MultihashToDonateId[_hash][hash_function][size] = donateId;
        DonateIdToMultihash[donateId] = Multihash(_hash,hash_function,size);
        DonateIdOwner[donateId] = msg.sender;

        uint256 eventIdx = growdrop.emitDonateActionEvent(
            msg.sender,
            address(0x0),
            address(0x0),
            address(0x0),
            address(0x0),
            donateId,
            0,
            2
        );
        emit DonateEvent(eventIdx, msg.sender, donateId, _hash, hash_function, size);
    }
    
    function mint(address supporter, address beneficiary, address token, uint256 amount, uint256 donateId) public returns (uint256) {
        require(msg.sender==address(growdrop));
        
        uint256 tokenId = uint256(keccak256(abi.encode(supporter, beneficiary, token, amount, donateId)));
        TokenIdToDonateInfo[tokenId] = DonateInfo(supporter,beneficiary,token,amount,donateId);
        
        _mint(supporter, tokenId);
        
        DonateInfoToTokenAmount[supporter][beneficiary][token][donateId] = DonateInfoToTokenAmount[supporter][beneficiary][token][donateId].add(amount);
        growdrop.emitDonateActionEvent(address(0x0), supporter, supporter, beneficiary, token, donateId, amount, 0);
        return tokenId;
    }
    
    function transferFrom(address _from, address to, uint256 tokenId) public {
        super.transferFrom(_from,to,tokenId);
        setInfoToTokenId(_from,to,tokenId);
    }
    
    function safeTransferFrom(address _from, address to, uint256 tokenId) public {
        super.safeTransferFrom(_from,to,tokenId);
        setInfoToTokenId(_from,to,tokenId);
    }
    
    function setInfoToTokenId(address _from, address to, uint256 tokenId) private {
        DonateInfo memory donateInfo = TokenIdToDonateInfo[tokenId];
        
        DonateInfoToTokenAmount[_from][donateInfo.beneficiary][donateInfo.tokenAddress][donateInfo.donateId] = DonateInfoToTokenAmount[_from][donateInfo.beneficiary][donateInfo.tokenAddress][donateInfo.donateId].sub(donateInfo.tokenAmount);
        DonateInfoToTokenAmount[to][donateInfo.beneficiary][donateInfo.tokenAddress][donateInfo.donateId] = DonateInfoToTokenAmount[to][donateInfo.beneficiary][donateInfo.tokenAddress][donateInfo.donateId].add(donateInfo.tokenAmount);
        growdrop.emitDonateActionEvent(_from,
        to,
        donateInfo.supporter,
        donateInfo.beneficiary,
        donateInfo.tokenAddress,
        donateInfo.donateId,
        donateInfo.tokenAmount,
        1);
    }
    
    function getDonateInfo(uint256 tokenId) public view returns (address, address, address, uint256, uint256) {
        DonateInfo memory donateInfo = TokenIdToDonateInfo[tokenId];
        return (donateInfo.supporter,
            donateInfo.beneficiary,
            donateInfo.tokenAddress,
            DonateInfoToTokenAmount[donateInfo.supporter][donateInfo.beneficiary][donateInfo.tokenAddress][donateInfo.donateId],
            donateInfo.donateId);
    }
    
    function getMultihash(uint256 donateId) public view returns (bytes32, uint8, uint8) {
        Multihash memory multihash = DonateIdToMultihash[donateId];
        return (multihash.hash, multihash.hash_function, multihash.size);
    }
}