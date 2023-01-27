// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

contract DMPS is
    Initializable,
    UUPSUpgradeable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdCounter;

    uint256 public tokenPrice;
    uint256 public totalSupply;
    uint256 public _totalMint;
    uint256 public salesStartTime;
    uint256 public blackListStartTime;
    uint256 public salesEndTime;

    string public baseURI;

    mapping(address => bool) public whiteList;
    mapping(address => uint256) public countOfUser;

    bytes32 public root;

    event UpdatedBaseURI(string baseURI);
    event NFTInfo(uint256 tokenId);
    event SalesTime(
        uint256 salesStartTime_,
        uint256 blackListStartTime_,
        uint256 salesEndTime_
    );

    function initialize() external initializer {
        __ERC721_init_unchained("kk", "kk");
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();

        tokenPrice = 35 * 10**14;
        totalSupply = 5555;
        salesStartTime = 1674651770;
        blackListStartTime = 1674652850;
        salesEndTime = 1674653450;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev token uri of particular token id
     * @param tokenId.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /* *
     * @dev update base uri by called with ONLY OWNER
     * @param uri.
     * Emit {UpdatedBaseURI} event.
     */
    function updateBaseURI(string memory uri) external onlyOwner nonReentrant {
        baseURI = uri;
        emit UpdatedBaseURI(baseURI);
    }

    /* *
     * @dev Mint single nft with ONLY OWNER
     * @param to - account
     * @param uri - token uri
     */
    function safeMint(address to) internal nonReentrant {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _totalMint += 1;
    }

    /* *
     * @dev Pause the contract (stopped state)
     * by caller with ONLY OWNER.
     *
     * - The contract must not be paused.
     *
     * Emits a {Paused} event.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /* *
     * @dev Unpause the contract (normal state)
     * by caller with ONLY OWNER.
     *
     * - The contract must be paused.
     *
     * Emits a {Unpaused} event.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    /* *
     * @dev white list the user
     * @param - Account
     */

    function updateRoot(bytes32 _root) public onlyOwner {
        root = _root;
    }

    /* *
     * @dev User can mint the token, with the token limit
     * @param count - number of token user mint
     */
    function tokenMint(uint256 count, bytes32[] calldata _tree)
        public
        payable
        userCount(count)
    {
        require(count == 1 || count == 2, "count should be 1 or 2");
        require(_totalMint <= totalSupply, "Exceed limit");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (MerkleProofUpgradeable.verify(_tree, root, leaf)) {
            require(
                salesStartTime <= block.timestamp &&
                    salesEndTime >= block.timestamp,
                "sales completed"
            );
        } else {
            require(
                blackListStartTime <= block.timestamp &&
                    salesEndTime >= block.timestamp,
                "sales completed"
            );
        }
        for (uint256 i = 1; i <= count; i++) {
            if (countOfUser[msg.sender] == 1) {
                safeMint(msg.sender);
                emit NFTInfo(_totalMint - 1);
            } else if (countOfUser[msg.sender] == 2) {
                require(msg.value == tokenPrice, "Amount should be 0.0035");
                safeMint(msg.sender);
                emit NFTInfo(_totalMint - 1);
            }
        }
    }

    /**
     * @dev withdraw the native currency from the contract - only owner can withdraw
     */
    function withdrawCurrency() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /* *
     * @dev owner can update the fee amount
     * @param updateWhiteListedTokenPrice, updateTokenPrice
     */
    function updateTokenPrice(uint256 _tokenPrice) external onlyOwner {
        tokenPrice = _tokenPrice;
    }

    /* *
     * @dev - owner can update the sales time
     * @param - salesStartTime - only whitelisted user, salesEndTime, blackListStartTime
     */

    function updateSalesTime(
        uint256 _salesStartTime,
        uint256 _salesEndTime,
        uint256 _blackListStartTime
    ) external onlyOwner {
        require(
            _salesStartTime < _salesEndTime &&
                _blackListStartTime <= _salesEndTime &&
                _salesEndTime < block.timestamp,
            "End time should be greater than the start time"
        );
        salesStartTime = _salesStartTime;
        salesEndTime = _salesEndTime;
        blackListStartTime = _blackListStartTime;

        emit SalesTime(_salesStartTime, _blackListStartTime, _salesEndTime);
    }

    /* *
     * @dev check the whitelistedUser
     * @param _tree
     */

    function isWhiteListAccount(bytes32[] calldata _tree)
        public
        view
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProofUpgradeable.verify(_tree, root, leaf),
            "Incorrect proof"
        );
        return true; // Or you can mint tokens here
    }

    /* *
     * @dev check the single user count
     * @param count
     */
    modifier userCount(uint256 count) {
        countOfUser[msg.sender] += count;
        require(countOfUser[msg.sender] <= 2, "User count is less than 3");
        _;
    }
}
