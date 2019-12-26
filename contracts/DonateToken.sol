
pragma solidity ^0.5.11;

import "./ERC721.sol";
import "./Growdrop.sol";

/**
 * @dev Implementation of ERC721 token which is used as donation deed,
 * and includes storing IPFS hash to identify Growdrop's donation. 
 */
contract DonateToken is ERC721 {
    /**
     * @notice Check whether address is admin.
     */
    mapping(address => bool) public CheckOwner;
    
    /**
     * @notice Current deployed Growdrop.
     */
    Growdrop growdrop;
    
    /**
     * @notice Container for IPFS hash.
     * @member hash digest of IPFS hash format
     * @member hash_function hash function code of IPFS hash format
     * @member size digest size of IPFS hash format
     */
    struct Multihash {
        bytes32 hash;
        uint8 hash_function;
        uint8 size;
    }
    
    /**
     * @notice Container for ERC721 token's donation information.
     * @member supporter address of Growdrop investor
     * @member beneficiary address of Growdrop investee or beneficiary
     * @member tokenAddress address of Growdrop's funding token
     * @member tokenAmount accrued interest amount of Growdrop investor
     * @member donateId Growdrop's donation identifier
     */
    struct DonateInfo {
        address supporter;
        address beneficiary;
        address tokenAddress;
        uint256 tokenAmount;
        uint256 donateId;
    }
    
    /**
     * @notice Accrued interest amount from supporter to beneficiary with token address and Growdrop's donation identifier.
     */ 
    mapping(
        address => mapping(
            address => mapping(
                address => mapping(
                    uint256 => uint256)))) public DonateInfoToTokenAmount;
    
    /**
     * @notice Donation information of ERC721 token identifier.
     */                 
    mapping(uint256 => DonateInfo) private TokenIdToDonateInfo;
    
    /**
     * @notice IPFS hash of Growdrop's donation identifier.
     */ 
    mapping(uint256 => Multihash) private DonateIdToMultihash;
    
    /**
     * @notice Owner of Growdrop's donation identifier.
     */ 
    mapping(uint256 => address) public DonateIdOwner;
    
    /**
     * @notice Growdrop's donation identifier of IPFS hash.
     */ 
    mapping(
        bytes32 => mapping(
            uint8 => mapping (
                uint8 => uint256))) public MultihashToDonateId;
    
    /**
     * @notice Event emitted when IPFS hash is stored.
     */ 
    event DonateEvent(
        uint256 indexed event_idx,
        address indexed from_address,
        uint256 indexed donate_id,
        bytes32 hash,
        uint8 hash_function,
        uint8 size
    );
    
    /**
     * @dev Constructor, storing deployer as admin,
     * and storing deployed Growdrop address.
     * @param _Growdrop Growdrop's deployed address
     */
    constructor (address payable _Growdrop) public {
        CheckOwner[msg.sender] = true;
        growdrop = Growdrop(_Growdrop);
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
     * @dev Stores new IPFS hash as a donation identifier
     * and owner as caller.
     * 
     * Emits {Growdrop-DonateAction} event indicating owner and donation identifier as 'donateId'.
     * 
     * @param _hash digest of IPFS hash format
     * @param hash_function hash function code of IPFS hash format
     * @param size digest size of IPFS hash format
     */
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
            0,
            2
        );
        emit DonateEvent(eventIdx, msg.sender, donateId, _hash, hash_function, size);
    }
    
    /**
     * @dev Mint a ERC721 token to 'supporter'.
     * 
     * Emits {Growdrop-DonateAction} event indicating new ERC721 token information.
     * 
     * @param supporter address of Growdrop's investor
     * @param beneficiary address of Growdrop's investee or 'beneficiary'
     * @param token address of Growdrop's funding token
     * @param amount accrued interest amount of investor
     * @param donateId Growdrop's donation identifier
     * @return tokenId new ERC721 token's identifier
     */
    function mint(address supporter, address beneficiary, address token, uint256 amount, uint256 donateId) public returns (uint256) {
        require(msg.sender==address(growdrop), "not growdrop contract");
        if(amount==0) return 0;
        
        uint256 tokenId = uint256(keccak256(abi.encode(supporter, beneficiary, token, amount, donateId)));
        TokenIdToDonateInfo[tokenId] = DonateInfo(supporter,beneficiary,token,amount,donateId);
        
        _mint(supporter, tokenId);
        
        DonateInfoToTokenAmount[supporter][beneficiary][token][donateId] = DonateInfoToTokenAmount[supporter][beneficiary][token][donateId].add(amount);
        growdrop.emitDonateActionEvent(address(0x0), supporter, supporter, beneficiary, token, donateId, tokenId, amount, 0);
        return tokenId;
    }
    
    /**
     * @dev Transfer 'tokenId' ERC721 token from '_from' to 'to'.
     * After transferring token, 'DonateInfoToTokenAmount' changes.
     * This does not change 'DonateInfo' of ERC721 token.
     * 
     * Emits {Growdrop-DonateAction} event indicating transfer of ERC721 token.
     * 
     * @param _from address of token owner
     * @param to address of token receiver
     * @param tokenId identifier of token
     */
    function transferFrom(address _from, address to, uint256 tokenId) public {
        super.transferFrom(_from,to,tokenId);
        setInfoToTokenId(_from,to,tokenId);
    }
    
    /**
     * @dev Safe Transfer 'tokenId' ERC721 token from '_from' to 'to'.
     * After transferring token, 'DonateInfoToTokenAmount' changes.
     * This does not change 'DonateInfo' of ERC721 token.
     * 
     * Emits {Growdrop-DonateAction} event indicating transfer of ERC721 token.
     * 
     * @param _from address of token owner
     * @param to address of token receiver
     * @param tokenId identifier of token
     */
    function safeTransferFrom(address _from, address to, uint256 tokenId, bytes memory _data) public {
        super.safeTransferFrom(_from,to,tokenId,_data);
        setInfoToTokenId(_from,to,tokenId);
    }
    
    /**
     * @dev Changes donation amount recalculated with '_from' and 'to'.
     * 
     * Emits {Growdrop-DonateAction} event.
     * 
     * @param _from address of token owner
     * @param to address of token receiver
     * @param tokenId identifier of token
     */
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
        tokenId,
        donateInfo.tokenAmount,
        1);
    }
    
    /**
     * @dev Get donation information of ERC721 token identifier.
     * @param tokenId identifier of token
     * @return donateInfo.supporter stored investor address of 'tokenId'
     * @return donateInfo.beneficiary stored investee or beneficiary address of 'tokenId'
     * @return donateInfo.tokenAddress stored funding token's address of 'tokenId'
     * @return donateInfo.tokenAmount stored accrued interest amount of 'tokenId'
     * @return donateInfo.donateId Growdrop's donation identifier of 'tokenId'
     */
    function getDonateInfo(uint256 tokenId) public view returns (address, address, address, uint256, uint256) {
        DonateInfo memory donateInfo = TokenIdToDonateInfo[tokenId];
        return (donateInfo.supporter,
            donateInfo.beneficiary,
            donateInfo.tokenAddress,
            donateInfo.tokenAmount,
            donateInfo.donateId);
    }
    
    /**
     * @dev Get stored IPFS hash of Growdrop's donation identifier.
     * @param donateId Growdrop's donation identifier
     * @return multihash.hash stored digest of IPFS hash format
     * @return multihash.hash_function stored hash function code of IPFS hash format
     * @return multihash.size stored digest size of IPFS hash format
     */
    function getMultihash(uint256 donateId) public view returns (bytes32, uint8, uint8) {
        Multihash memory multihash = DonateIdToMultihash[donateId];
        return (multihash.hash, multihash.hash_function, multihash.size);
    }
}
