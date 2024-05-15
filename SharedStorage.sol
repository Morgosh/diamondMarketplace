// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

library SharedStorage {
    struct Storage {
        uint256 chainId;
        address wethAddress;
        address premiumNftAddress;
        uint256 platformFee;
        //address platformFeeRecipient; now is withdrawable by owner
        uint256 premiumDiscount;
        string name;
        string version;
        bool paused;
        mapping (bytes32 => bool) ordersClaimed; // Tracks if a listing has been claimed
        mapping (address => uint256) ordersCanceledAt; // below the date all orders are canceled
    }

    function getStorage() internal pure returns (Storage storage ds) {
        bytes32 position = keccak256("org.eip2535.diamond.storage");
        assembly {
            ds.slot := position
        }
    }

    function setChainId(uint256 _chainId) internal {
        getStorage().chainId = _chainId;
    }

    function setWETHAddress(address _wethAddress) internal {
        getStorage().wethAddress = _wethAddress;
    }

    function setPremiumNftAddress(address _premiumNftAddress) internal {
        getStorage().premiumNftAddress = _premiumNftAddress;
    }

    function setPlatformFee(uint256 _platformFee) internal {
        getStorage().platformFee = _platformFee;
    }

    // function setPlatformFeeRecipient(address _platformFeeRecipient) internal {
    //     getStorage().platformFeeRecipient = _platformFeeRecipient;
    // }

    function setPremiumDiscount(uint256 _premiumDiscount) internal {
        getStorage().premiumDiscount = _premiumDiscount;
    }

    function setName(string memory _name) internal {
        getStorage().name = _name;
    }

    function setVersion(string memory _version) internal {
        getStorage().version = _version;
    }

    function setPaused(bool _paused) internal {
        getStorage().paused = _paused;
    }

}
