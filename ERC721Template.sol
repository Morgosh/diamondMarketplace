//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ERC721A.sol";

contract ERC721Template is IERC2981, Ownable, ERC721A  {
    using Strings for uint256;

    string private baseURI;
    string public notRevealedURI;
    uint256 public maxSupply;
    uint256 public publicPrice;
    uint256 public publicMaxMintAmount;
    uint256 public publicSaleStartTime = type(uint256).max;
    bool public isRevealed;
    address payable public withdrawalRecipientAddress; // address that will receive revenue
    
    address payable public comissionRecipientAddress;// address that will receive a part of revenue on withdrawal
    uint256 public comissionPercentageIn10000; // percentage of revenue to be sent to comissionRecipientAddress
    uint256 private totalComissionWithdrawn = 0;    
    uint256 private fixedCommissionTreshold;

    string public contractURI;
    //presale price is set after

    // Default royalty info
    address payable public defaultRoyaltyRecipient;
    uint256 public defaultRoyaltyPercentageIn10000;
    // Per-token royalty info
    mapping(uint256 => address payable) public tokenRoyaltyRecipient;
    mapping(uint256 => uint256) public tokenRoyaltyPercentage;

    event ContractURIUpdated();

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _contractURI,
        uint256 _maxSupply,
        uint256 _publicPrice,
        string memory _defaultBaseURI,
        string memory _notRevealedURI,
        address payable _withdrawalRecipientAddress,
        address payable _comissionRecipientAddress,
        uint256 _fixedCommisionTreshold,
        uint256 _comissionPercentageIn10000,
        address payable _defaultRoyaltyRecipient, // separate from withdrawal recipient to enhance security
        uint256 _defaultRoyaltyPercentageIn10000
        // set max mint amount after deployment
    ) ERC721A(_name, _symbol) Ownable(msg.sender) {
        setMaxSupply(_maxSupply);
        setPublicPrice(_publicPrice);
        contractURI = _contractURI; // no need to emit event here, as it's set in the constructor
        setBaseURI(_defaultBaseURI);
        setNotRevealedURI(_notRevealedURI);
        publicMaxMintAmount = 10000;
        withdrawalRecipientAddress = _withdrawalRecipientAddress;
        comissionRecipientAddress = _comissionRecipientAddress;
        fixedCommissionTreshold = _fixedCommisionTreshold;
        // Ensure commission percentage is between 0 and 10000 (0-100%)
        require(_comissionPercentageIn10000 <= 10000, "Invalid commission percentage");
        comissionPercentageIn10000 = _comissionPercentageIn10000;
        defaultRoyaltyRecipient = _defaultRoyaltyRecipient;
        defaultRoyaltyPercentageIn10000 = _defaultRoyaltyPercentageIn10000;
        isRevealed = keccak256(abi.encodePacked(_notRevealedURI)) == keccak256(abi.encodePacked("")) || 
            keccak256(abi.encodePacked(_notRevealedURI)) == keccak256(abi.encodePacked("null"));
    }

    // //onchain metadata, offchain image
    // //import "./Base64.sol";
    // function tokenURI(
    //     uint256 tokenId
    // ) public view virtual override returns (string memory) {
    //     bytes memory dataURI = abi.encodePacked(
    //         '{',
    //             '"name": "Chain Battles #', tokenId.toString(), '",',
    //             '"description": "Battles on chain",',
    //             '"image": "', generateCharacter(tokenId), '"',
    //         '}'
    //     );
    //     return string(
    //         abi.encodePacked(
    //             "data:application/json;base64,",
    //             Base64.encode(dataURI)
    //         )
    //     );
    // }
    
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(
            ownerOf(tokenId) != address(0),
            "ERC721Metadata: URI query for nonexistent token"
        );
        if (isRevealed == false) {
            return notRevealedURI;
        }
        string memory identifier = tokenId.toString();
        return
            bytes(baseURI).length != 0
                ? string(abi.encodePacked(baseURI, identifier, ".json"))
                : "";
    }

    function getPublicMintEligibility() public view returns (uint256) {
        return publicMaxMintAmount - balanceOf(msg.sender);
    }

    // !important, if you use burnable, mint wont work properly, imagine 5 tokens minted, burning token 1, you try to mint, you would override token 5
    function mint(uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();
        require(supply + _mintAmount <= maxSupply, "Total supply exceeded");
        require(block.timestamp >= publicSaleStartTime, "Public sale not active");
        require(_mintAmount > 0, "You have to mint alteast one");
        require(getPublicMintEligibility() >= _mintAmount, "Invalid amount to be minted");
        require(msg.value >= publicPrice * _mintAmount, "Cost is higher than the amount sent");
        require(balanceOf(msg.sender) + _mintAmount <= publicMaxMintAmount, "Invalid amount to be minted"); // we can't enforce this, but this comes in handy
        _safeMint(msg.sender, _mintAmount);
    }

    function adminMint(address _to, uint256 _mintAmount) public onlyOwner {
        uint256 supply = totalSupply();
        _safeMint(_to, _mintAmount);
    }

    function batchAdminMint(address[] calldata recipients) external onlyOwner {
        for (uint256 i = 0; i < recipients.length; i++) {
            adminMint(recipients[i], 1);
        }
    }

    function setPublicPrice(uint256 _newPrice) public onlyOwner {
        publicPrice = _newPrice;
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedURI = _notRevealedURI;
    }

    function setMaxSupply(uint256 _newmaxSupply) public onlyOwner {
        maxSupply = _newmaxSupply;
    }

    function togglePublicSaleActive() external onlyOwner {
        if (block.timestamp < publicSaleStartTime) {
            publicSaleStartTime = block.timestamp;
        } else {
            // This effectively disables the public sale by setting the start time to a far future
            publicSaleStartTime = type(uint256).max;
        }
    }

    // Sets the start time of the public sale to a specific timestamp
    function setPublicSaleStartTime(uint256 _publicSaleStartTime) external onlyOwner {
        publicSaleStartTime = _publicSaleStartTime;
    }

    function setPublicMaxMintAmount(uint256 _publicMaxMintAmount) external onlyOwner {
        publicMaxMintAmount = _publicMaxMintAmount;
    }

    function toggleReveal() external onlyOwner {
        isRevealed = !isRevealed;
    }

    // existing functions

    function setDefaultRoyaltyInfo(address payable _defaultRoyaltyRecipient, uint256 _defaultRoyaltyPercentageIn10000) public onlyOwner {
        defaultRoyaltyRecipient = _defaultRoyaltyRecipient;
        defaultRoyaltyPercentageIn10000 = _defaultRoyaltyPercentageIn10000;
    }

    function setTokenRoyaltyInfo(uint256 _tokenId, address payable _royaltyRecipient, uint256 _royaltyPercentage) public onlyOwner {
        require(ownerOf(_tokenId) != address(0), "Token does not exist");
        tokenRoyaltyRecipient[_tokenId] = _royaltyRecipient;
        tokenRoyaltyPercentage[_tokenId] = _royaltyPercentage;
    }
    
    function setContractURI(string memory newURI) external onlyOwner {
        contractURI = newURI;
        emit ContractURIUpdated();
    }

    // implement ERC2981
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view override returns (address, uint256) {
        uint256 royaltyPercentage = tokenRoyaltyPercentage[_tokenId] != 0 ? tokenRoyaltyPercentage[_tokenId] : defaultRoyaltyPercentageIn10000;
        address royaltyRecipient = tokenRoyaltyRecipient[_tokenId] != address(0) ? tokenRoyaltyRecipient[_tokenId] : defaultRoyaltyRecipient;
        return (royaltyRecipient, (_salePrice * royaltyPercentage) / 10000);
    }

    function withdrawFixedComission() external {
        require(
            msg.sender == owner() || msg.sender == comissionRecipientAddress,
            "Only owner or commission recipient can withdraw"
        );
        uint256 remainingCommission = fixedCommissionTreshold - totalComissionWithdrawn;
        uint256 amount = remainingCommission > address(this).balance 
                        ? address(this).balance 
                        : remainingCommission;

        // Ensure that the contract balance is sufficient before proceeding
        require(address(this).balance >= amount, "Insufficient balance");
        // Ensure we don't exceed the fixed commission threshold
        require(totalComissionWithdrawn + amount <= fixedCommissionTreshold, "Total withdrawal by commission cannot exceed the threshold");

        // Updating the total withdrawn by A before making the transfer
        totalComissionWithdrawn += amount;
        (bool success, ) = comissionRecipientAddress.call{value: amount}("");
        require(success, "Transfer failed");
    }


    function withdraw() external virtual {
        require(totalComissionWithdrawn >= fixedCommissionTreshold, "Threshold for A must be reached first");
        require(
            msg.sender == owner() || msg.sender == comissionRecipientAddress  || msg.sender == withdrawalRecipientAddress,
            "Only owner or commission recipient can withdraw"
        );

        uint256 comission = (address(this).balance * comissionPercentageIn10000) /
            10000; // Divide by 10000 instead of 100
        uint256 ownerAmount = address(this).balance - comission;

        if (comission > 0) {
            (bool cs, ) = comissionRecipientAddress.call{value: comission}("");
            require(cs);
        }

        if (ownerAmount > 0) {
            (bool os, ) = withdrawalRecipientAddress.call{value: ownerAmount}("");
            require(os);
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721A, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || 
            ERC721A.supportsInterface(interfaceId) || 
            super.supportsInterface(interfaceId);
    }

    // Override _startTokenId if you want your token IDs to start from 1 instead of 0
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }
}