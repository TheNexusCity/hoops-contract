// SPDX-License-Identifier: MIT
// Creator: Shawbot @ The Nexus
// Modified ERC721A contract by Chiru Labs

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';

/// @title IERC2981Royalties
/// @dev Interface for the ERC2981 - Token Royalty standard
interface IERC2981Royalties {
    /// @notice Called with the sale price to determine how much royalty
    //          is owed and to whom.
    /// @param _tokenId - the NFT asset queried for royalty information
    /// @param _value - the sale price of the NFT asset specified by _tokenId
    /// @return _receiver - address of who should be sent the royalty payment
    /// @return _royaltyAmount - the royalty payment amount for value sale price
    function royaltyInfo(uint256 _tokenId, uint256 _value)
        external
        view
        returns (address _receiver, uint256 _royaltyAmount);
}

// mint price of hoops
// whitelist -- .0824
// mint price -- .1
// mint max -- 20

// Hoops
// HOOPS

// royalty percentage - 10%

// owner address + seed phrase + private key

// art editable

// 

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata and Enumerable extension. Built to optimize for lower gas during batch mints.
 *
 * Assumes serials are sequentially minted starting at 0 (e.g. 0, 1, 2, 3..).
 *
 * Does not support burning tokens to address(0).
 *
 * Assumes that an owner cannot have more than the 2**128 - 1 (max value of uint128) of supply
 */

contract Hoops is ERC165, IERC721, IERC721Metadata, IERC721Enumerable, IERC2981Royalties {
    using Address for address;
    using Strings for uint256;

    address _treasuryAddress;

    string private _baseURI = '';

    string private _uriSuffix = '';

    uint private _whitelistedMintPrice = 0.0824 ether;

    uint private _mintPrice = 0.1 ether;

    uint private _maxMintQuantity = 20;

    bool _anyoneCanMint = false;

    struct TokenOwnership {
        address addr;
        uint64 startTimestamp;
    }

    struct AddressData {
        uint128 balance;
        uint128 numberMinted;
    }

    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    function getMintPrice() public view returns (uint) {
        return _anyoneCanMint ? _mintPrice : _whitelistedMintPrice;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function transferOwnership(address owner) public virtual onlyOwner {
        _owner = owner;
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor(address treasuryAddress) {
        _owner = msg.sender;
        _treasuryAddress = treasuryAddress;
    }

    function withdraw() public onlyTreasurerOrOwner {
        // This will transfer the remaining contract balance to the owner.
        // Do not remove this otherwise you will not be able to withdraw the funds.
        (bool os, ) = payable(_treasuryAddress).call{value: address(this).balance}('');
        require(os);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == msg.sender, 'Ownable: caller is not the owner');
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner or treasurer.
     */
    modifier onlyTreasurerOrOwner() {
        require(_owner == msg.sender, 'Ownable: caller is not the owner');
        _;
    }

    modifier onlyValidAccess(
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) {
        bytes32 hash = keccak256(abi.encodePacked(this, msg.sender));
        require(
            _owner == ecrecover(keccak256(abi.encodePacked('\x19Ethereum Signed Message:\n32', hash)), _v, _r, _s) ||
                _owner == msg.sender ||
                _anyoneCanMint,
            'invalidaccess'
        );
        _;
    }

    function setOpenMint(bool anyoneCanMint) public onlyOwner {
        _anyoneCanMint = anyoneCanMint;
    }

    function royaltyInfo(uint256, uint256 value)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        return (_treasuryAddress, value / 10); // 10% royalty
    }

    uint256 internal currentIndex;

    // Mapping from token ID to ownership details
    // An empty struct value does not necessarily mean the token is unowned. See ownershipOf implementation for details.
    mapping(uint256 => TokenOwnership) internal _ownerships;

    // Mapping owner address to address data
    mapping(address => AddressData) private _addressData;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return currentIndex;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view override returns (uint256) {
        require(index < currentIndex, 'idx>bnds'); // global index out of bounds
        return index;
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     * This read function is O(totalSupply). If calling from a separate contract, be sure to test gas first.
     * It may also degrade with extremely large collection sizes (e.g >> 10000), test for your use case.
     */
    function tokenOfOwnerByIndex(address tokenOwner, uint256 index) public view override returns (uint256) {
        require(index < balanceOf(tokenOwner), 'oIdx>bnds'); //  owner index out of bounds
        uint256 tokenIdsIdx;
        address currOwnershipAddr;

        // Counter overflow is impossible as the loop breaks when uint256 i is equal to another uint256 numMintedSoFar.
        unchecked {
            for (uint256 i; i < currentIndex; i++) {
                TokenOwnership memory ownership = _ownerships[i];
                if (ownership.addr != address(0) && ownership.addr == tokenOwner ) {
                   if (tokenIdsIdx == index) {
                        return i;
                    }
                    tokenIdsIdx++;
                }
            }
        }

        revert('notoken'); //  unable to get token of owner by index
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC721Enumerable).interfaceId ||
            interfaceId == type(IERC2981Royalties).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view override returns (uint256) {
        require(owner != address(0), '0x'); //  balance query for the zero address
        return uint256(_addressData[owner].balance);
    }

    function _numberMinted(address owner) internal view returns (uint256) {
        require(owner != address(0), '0x'); //  number minted query for the zero address
        return uint256(_addressData[owner].numberMinted);
    }

    /**
     * Gas spent here starts off proportional to the maximum mint batch size.
     * It gradually moves to O(1) as tokens get transferred around in the collection over time.
     */
    function ownershipOf(uint256 tokenId) internal view returns (TokenOwnership memory) {
        require(_exists(tokenId), 'notoken'); //  owner query for nonexistent token

        unchecked {
            TokenOwnership memory ownership = _ownerships[tokenId];
            if (ownership.addr != address(0)) {
                return ownership;
            }
        }

        revert('noowner'); //  unable to determine the owner of token
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        return ownershipOf(tokenId).addr;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return 'Hoops';
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return 'HOOPS';
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), 'notoken'); // ERC721Metadata: URI query for nonexistent token
        return bytes(_baseURI).length != 0 ? string(abi.encodePacked(_baseURI, tokenId.toString(), _uriSuffix)) : '';
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseURI = baseURI;
    }

    function setUriSuffix(string memory uriSuffix) public onlyOwner {
        _uriSuffix = uriSuffix;
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public override {
        address owner = Hoops.ownerOf(tokenId);
        require(to != owner, 'notowner'); //  approval to current owner

        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            'notapproved' //  approve caller is not owner nor approved for all
        );

        _approve(to, tokenId, owner);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view override returns (address) {
        require(_exists(tokenId), 'notoken'); //  approved query for nonexistent token

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public override {
        require(operator != msg.sender, 'notcaller'); //  approve to caller

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, '');
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override {
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, _data),
            'not721' //  transfer to non ERC721Receiver implementer
        );
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId < currentIndex;
    }

    function goat() public pure returns (string memory) {
        return '"Greatness is defined by how much you want to put into what you do." - LeBron James';
    }

    // Mint for self without a whitelist validation
    function mint(
        uint256 quantity
    ) public payable {
        _mint(msg.sender, quantity, 0, 0, 0);
    }

    // Mint for self without a whitelist validation
    function mintForAddress(
        uint256 quantity,
        address to
    ) public payable {
        _mint(to, quantity, 0, 0, 0);
    }


    // Mint for self without a whitelist validation
    function mintForAddress(
        uint256 quantity,
        address to,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public payable onlyValidAccess(_v, _r, _s) {
        _mint(to, quantity, _v, _r, _s);
    }

    // Mint for self with a whitelist validation
    function mint(
        uint256 quantity,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public payable {
        _mint(msg.sender, quantity, _v, _r, _s);
    }

    /**
     * @dev Mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `quantity` must be greater than 0.
     *
     * Emits a {Transfer} event.
     */
    function _mint(
        address to,
        uint256 quantity,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal onlyValidAccess(_v, _r, _s) {
        require(to != address(0), 'Cannot send to 0x0'); // mint to the 0x0 address
        require(quantity != 0, 'Quantity cannot be 0'); // quantity must be greater than 0
        require(quantity <= _maxMintQuantity, 'Quantity exceeds mint max'); // quantity must be 5 or less
        require(msg.value >= (_anyoneCanMint ? _mintPrice : _whitelistedMintPrice) * quantity, "Insufficient funds!");
        require(currentIndex <= 10000, 'No Hoops left!'); // sold out
        require(currentIndex + quantity <= 10000, 'Not enough Hoops left!'); // cannot mint more than maxIndex tokens

        unchecked {
            _addressData[to].balance += uint128(quantity);
            _addressData[to].numberMinted += uint128(quantity);
            for (uint256 i; i < quantity; i++) {
                emit Transfer(address(0), to, currentIndex);
                require(
                    _checkOnERC721Received(address(0), to, currentIndex, ''),
                    'Not ERC721Receiver' // transfer to non ERC721Receiver implementer
                );
                _ownerships[currentIndex].addr = to;
                _ownerships[currentIndex].startTimestamp = uint64(block.timestamp);
                currentIndex++;
            }
        }
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) private {
        TokenOwnership memory prevOwnership = ownershipOf(tokenId);

        bool isApprovedOrOwner = (msg.sender == prevOwnership.addr ||
            getApproved(tokenId) == msg.sender ||
            isApprovedForAll(prevOwnership.addr, msg.sender));

        require(isApprovedOrOwner, 'notapproved'); //  transfer caller is not owner nor approved

        require(prevOwnership.addr == from, 'badowner'); // transfer from incorrect owner
        require(to != address(0), '0x'); //  transfer to the zero address

        // Clear approvals from the previous owner
        _approve(address(0), tokenId, prevOwnership.addr);

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as tokenId would have to be 2**256.
        unchecked {
            _addressData[from].balance -= 1;
            _addressData[to].balance += 1;

            _ownerships[tokenId].addr = to;
            _ownerships[tokenId].startTimestamp = uint64(block.timestamp);
        }

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(
        address to,
        uint256 tokenId,
        address owner
    ) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert('not721'); //  transfer to non ERC721Receiver implementer
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
}
