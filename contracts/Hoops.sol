// SPDX-License-Identifier: MIT
// Created by Shawbot & Supernftier @ The Nexus
// Based on ERC721A contract by Chiru Labs

pragma solidity 0.8.13;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';

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

contract Hoops is ERC165, IERC721, IERC721Metadata, IERC721Enumerable {
    using Address for address;
    using Strings for uint256;

    address _treasuryAddress = 0x87Bc1aC91E5BeC68BCe0427A0E627828F7c52a67;

    string private _baseURI = '';

    string private _unrevealedBaseURI = '';

    string private _uriSuffix = '';

    uint private _mintPrice = 0.0824 ether;

    uint private _maxMintQuantity = 25;

    uint private _maxSupply = 10000;

    bool _mintIsOpen = false;

    uint private _revealIndex = 0;

    bool _stickersEnabled = false;

    function setStickersEnabled(bool _newStickersEnabled) public onlyOwner {
        _stickersEnabled = _newStickersEnabled;
    }

    mapping(uint256 => string) internal _stickerURIs;

    function setStickerUri(uint256 tokenId, string memory uri) public {
        require(_stickersEnabled || msg.sender == _owner, "Stickers are not enabled");
        require(ownerOf(tokenId) == msg.sender || msg.sender == _owner, "Only the token owner can set the sticker URI");
        require(bytes(_stickerURIs[tokenId]).length == 0, "Cannot set uri twice"); 
        _stickerURIs[tokenId] = uri; 
    }

    function hasStickers(uint256 tokenId) public view returns (bool) {
        require(_stickersEnabled || msg.sender == _owner, "Stickers are not enabled");
        return bytes(_stickerURIs[tokenId]).length != 0;
    }

    function getStickerUri(uint256 tokenId) public view returns (string memory) {
        require(_stickersEnabled || msg.sender == _owner, "Stickers are not enabled");
        // TASK: return true if the sticker URI is set in _stickerURIs mapping and false if it is an empty string
        if(bytes(_stickerURIs[tokenId]).length > 0){
            return _stickerURIs[tokenId];
        }
        return "";
    }

    function resetStickers(uint256 tokenId) public {
        require(_stickersEnabled || msg.sender == _owner, "Stickers are not enabled");
        require(ownerOf(tokenId) == msg.sender || msg.sender == _owner, "Only the owner can reset sticker uri");
        _stickerURIs[tokenId] = "";
    }

    // reset sticker uri (tokenid) only owner of sticker

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
        return _mintPrice;
    }

    // Set the _mintPrice to a new value in ether if the msg.sender is the _owner
    function setMintPrice(uint newPrice) public onlyOwner {
        _mintPrice = newPrice;
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
    constructor() {
        _owner = msg.sender;
    }

    function withdraw() public onlyTreasurerOrOwner {
        // This will transfer the remaining contract balance to the owner.
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

    modifier onlyValidAccess() {
        require(_owner == msg.sender || _mintIsOpen, 'You are not the owner and the mint is not open');
        _;
    }

    function isMintOpen() public view returns (bool) {
        return _mintIsOpen;
    }

    function setOpenMint(bool mintIsOpen) public onlyOwner {
        _mintIsOpen = mintIsOpen;
    }

    uint256 internal currentIndex = 1;

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
        return currentIndex - 1;
    }

    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    function availableSupply() public view returns (uint256) {
        return _maxSupply - (currentIndex - 1);
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view override returns (uint256) {
        require(index < currentIndex && index > 0, 'Index must be between 1 and 10,000');
        return index;
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     * This read function is O(totalSupply). If calling from a separate contract, be sure to test gas first.
     * It may also degrade with extremely large collection sizes (e.g >> 10000), test for your use case.
     */
    function tokenOfOwnerByIndex(address tokenOwner, uint256 index) public view override returns (uint256) {
        require(index < balanceOf(tokenOwner), 'Owner index is out of bounds');
        uint256 tokenIdsIdx;
        address currOwnershipAddr;

        // Counter overflow is impossible as the loop breaks when uint256 i is equal to another uint256 numMintedSoFar.
        unchecked {
            for (uint256 i = 1; i < currentIndex; i++) {
                TokenOwnership memory ownership = _ownerships[i];
                if (ownership.addr != address(0)) {
                    currOwnershipAddr = ownership.addr;
                }
                if (currOwnershipAddr == tokenOwner) {
                    if (tokenIdsIdx == index) {
                        return i;
                    }
                    tokenIdsIdx++;
                }
            }
        }

        revert('No token found'); //  unable to get token of owner by index
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC721Enumerable).interfaceId ||
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
        require(_exists(tokenId), 'No token found'); //  owner query for nonexistent token

        unchecked {
            for (uint256 curr = tokenId; curr >= 0; curr--) {
                TokenOwnership memory ownership = _ownerships[curr];
                if (ownership.addr != address(0)) {
                    return ownership;
                }
            }
        }

        revert('No owner'); //  unable to determine the owner of token
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
        require(_exists(tokenId), 'No token found'); // ERC721Metadata: URI query for nonexistent token
        if(_stickersEnabled && hasStickers(tokenId)){
            return _stickerURIs[tokenId];
        }
        return bytes(_baseURI).length != 0 ? string(abi.encodePacked(tokenId < _revealIndex ? _baseURI : _unrevealedBaseURI, tokenId.toString(), _uriSuffix)) : '';
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseURI = baseURI;
    }

    function setUnrevealBaseURI(string memory baseURI) public onlyOwner {
        _unrevealedBaseURI = baseURI;
    }

    function setRevealIndex(uint index) public onlyOwner {
        _revealIndex = index;
    }

    function setUriSuffix(string memory uriSuffix) public onlyOwner {
        _uriSuffix = uriSuffix;
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public override {
        address owner = Hoops.ownerOf(tokenId);
        require(to != owner, 'Only the owner can call this function'); //  approval to current owner

        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            'Not approved' //  approve caller is not owner nor approved for all
        );

        _approve(to, tokenId, owner);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view override returns (address) {
        require(_exists(tokenId), 'No token found'); //  approved query for nonexistent token

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public override {
        require(operator != msg.sender, 'Not the caller'); //  approve to caller

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
        return tokenId < currentIndex && tokenId > 0;
    }

    function goat() public pure returns (string memory) {
        return '"Greatness is defined by how much you want to put into what you do." - LeBron James';
    }

    function mintForAddress(
        uint256 quantity,
        address to
    ) public payable onlyValidAccess() {
        _mint(to, quantity);
    }

    function mint(
        uint256 quantity
    ) public payable {
        _mint(msg.sender, quantity);
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
        uint256 quantity
    ) internal onlyValidAccess() {
        uint256 startTokenId = currentIndex;
        require(_owner == msg.sender || _mintIsOpen, 'Minting is currently closed'); // Don't allow anyone to mint if the mint is closed
        require(to != address(0), 'Cannot send to 0x0'); // mint to the 0x0 address
        require(quantity != 0, 'Quantity cannot be 0'); // quantity must be greater than 0
        require(_owner == msg.sender || quantity <= _maxMintQuantity, 'Quantity exceeds mint max'); // quantity must be less than max quantity
        // The owner can mint for free, everyone else needs to pay the price
        require(_owner == msg.sender || msg.value >= _mintPrice * quantity, "Insufficient funds!");
        require(currentIndex <= _maxSupply, 'No Hoops left!'); // sold out
        require(currentIndex + quantity <= _maxSupply, 'Not enough Hoops left to buy!'); // cannot mint more than maxIndex tokens

        _beforeTokenTransfers(address(0), to, startTokenId, quantity);

        unchecked {
            _addressData[to].balance += uint128(quantity);
            _addressData[to].numberMinted += uint128(quantity);

            _ownerships[startTokenId].addr = to;
            _ownerships[startTokenId].startTimestamp = uint64(block.timestamp);

            uint256 updatedIndex = startTokenId;

            for (uint256 i; i < quantity; i++) {
                emit Transfer(address(0), to, updatedIndex);
                    require(
                        _checkOnERC721Received(address(0), to, updatedIndex, ''),
                        'Not ERC721Receiver' // transfer to non ERC721Receiver implementer
                    );

                updatedIndex++;
            }

            currentIndex = updatedIndex;
        }
        _afterTokenTransfers(address(0), to, startTokenId, quantity);
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

        require(isApprovedOrOwner, 'Notapproved'); //  transfer caller is not owner nor approved
        require(prevOwnership.addr == from, 'Invalid Owner'); // transfer from incorrect owner
        require(to != address(0), '0x'); //  transfer to the zero address

        _beforeTokenTransfers(from, to, tokenId, 1);

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

            // If the ownership slot of tokenId+1 is not explicitly set, that means the transfer initiator owns it.
            // Set the slot of tokenId+1 explicitly in storage to maintain correctness for ownerOf(tokenId+1) calls.
            uint256 nextTokenId = tokenId + 1;
            if (_ownerships[nextTokenId].addr == address(0)) {
                if (_exists(nextTokenId)) {
                    _ownerships[nextTokenId].addr = prevOwnership.addr;
                    _ownerships[nextTokenId].startTimestamp = prevOwnership.startTimestamp;
                }
            }
        }

        emit Transfer(from, to, tokenId);
        _afterTokenTransfers(from, to, tokenId, 1);
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

    /**
     * @dev Hook that is called before a set of serially-ordered token ids are about to be transferred. This includes minting.
     *
     * startTokenId - the first token id to be transferred
     * quantity - the amount to be transferred
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     */
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}

    /**
     * @dev Hook that is called after a set of serially-ordered token ids have been transferred. This includes
     * minting.
     *
     * startTokenId - the first token id to be transferred
     * quantity - the amount to be transferred
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     */
    function _afterTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}
}
