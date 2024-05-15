//SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721Template.sol";

contract ERC721Merkle is ERC721Template {
    struct Tier {
        bytes32 merkleRoot;
        uint256 price;
        uint256 maxMintAmount;
        uint256 saleStartTime;
        mapping(address => uint256) mints;
    }
    mapping(uint256 => Tier) public tiers;
    uint256[] public tierIds;

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
    ) ERC721Template(
        _name,
        _symbol,
        _contractURI,
        _maxSupply,
        _publicPrice,
        _defaultBaseURI,
        _notRevealedURI,
        _withdrawalRecipientAddress,
        _comissionRecipientAddress,
        _fixedCommisionTreshold,
        _comissionPercentageIn10000,
        _defaultRoyaltyRecipient,
        _defaultRoyaltyPercentageIn10000
    ) {
        // add code here if you want to do something specific during contract deployment
    }

    function setTier(uint256 tierId, bytes32 merkleRoot, uint256 price, uint256 maxMintAmount, uint256 saleStartTime) external onlyOwner {
        Tier storage tier = tiers[tierId];
        tier.merkleRoot = merkleRoot;
        tier.price = price;
        tier.maxMintAmount = maxMintAmount;
        tier.saleStartTime = saleStartTime; // type(uint256).max; is used to disable the tier
        // check if tierId is already in the array
        bool isNewTierId = true;
        for (uint256 i = 0; i < tierIds.length; i++) {
            if (tierIds[i] == tierId) {
                isNewTierId = false;
                break;
            }
        }
        if (isNewTierId) {
            tierIds.push(tierId);
        }
    }

    //helper to disable a tier
    function disableTier(uint256 tierId) external onlyOwner {
        tiers[tierId].saleStartTime = type(uint256).max;
    }

    // enable a tier
    function enableTier(uint256 tierId) external onlyOwner {
        tiers[tierId].saleStartTime = 0;
    }

    function getTierIds() external view returns (uint256[] memory) {
        return tierIds;
    }

    // get how many more the user is eligible to mint
    function getMintEligibility(uint256 tierId, address user, bytes32[] calldata proof) external view returns (uint256) {
        //require(MerkleProof.verify(proof, tier.merkleRoot, keccak256(abi.encodePacked(msg.sender))), "Not in presale list for this tier");
        // return 0 if user is not in the merkleRoot
        if (!MerkleProof.verify(proof, tiers[tierId].merkleRoot, keccak256(abi.encodePacked(user)))) {
            return 0;
        }
        return tiers[tierId].maxMintAmount - tiers[tierId].mints[user];
    }

    // set startTime
    function setTierSaleStartTime(uint256 tierId, uint256 saleStartTime) external onlyOwner {
        require(tiers[tierId].merkleRoot != bytes32(0), "Tier does not exist");
        tiers[tierId].saleStartTime = saleStartTime;
    }

    // set price
    function setTierPrice(uint256 tierId, uint256 price) external onlyOwner {
        require(tiers[tierId].merkleRoot != bytes32(0), "Tier does not exist");
        tiers[tierId].price = price;
    }

    // set maxMintAmount
    function setTierMaxMintAmount(uint256 tierId, uint256 maxMintAmount) external onlyOwner {
        require(tiers[tierId].merkleRoot != bytes32(0), "Tier does not exist");
        tiers[tierId].maxMintAmount = maxMintAmount;
    }

    // set merkleRoot
    function setTierMerkleRoot(uint256 tierId, bytes32 merkleRoot) external onlyOwner {
        require(tiers[tierId].merkleRoot != bytes32(0), "Tier does not exist");
        tiers[tierId].merkleRoot = merkleRoot;
    }

    function getTierDetails(uint256 tierId) external view returns (bytes32 merkleRoot, uint256 price, uint256 maxMintAmount, uint256 saleStartTime) {
        Tier storage tier = tiers[tierId];
        return (tier.merkleRoot, tier.price, tier.maxMintAmount, tier.saleStartTime);
    }

    function whitelistMint(
        uint256 tierId,
        uint256 amount,
        bytes32[] calldata proof
    ) external payable {
        Tier storage tier = tiers[tierId];
        require(tier.merkleRoot != bytes32(0), "Tier does not exist");
        require(tier.saleStartTime != type(uint256).max, "Tier is not active");
        require(block.timestamp >= tier.saleStartTime, "Tier sale not started");
        require(MerkleProof.verify(proof, tier.merkleRoot, keccak256(abi.encodePacked(msg.sender))), "Not in presale list for this tier");
        require(amount <= tier.maxMintAmount - tier.mints[msg.sender], "Exceeds tier max mint amount");
        require(msg.value >= amount * tier.price, "Insufficient funds for mint");
        
        uint256 supply = totalSupply();
        require(supply + amount <= maxSupply, "Exceeds max supply");
        
        tier.mints[msg.sender] += amount;
        _safeMint(msg.sender, amount);
    }
}