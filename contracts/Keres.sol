pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Keres is ERC1155, AccessControl {
  ///baseURI is the root folder for skin img storage
  constructor(string memory baseURI) ERC1155(baseURI) {
    //minter role is `MINTER`
    //Make the deployer an overlord
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    //Make the admin a minter
    grantRole(MINTER, _msgSender());
  }

  //track all available item IDs
  mapping(uint256 => bool) private exists;

  mapping(string => bool) categoryExists;
  //Track used limits per MINTER
  mapping(address => mapping(uint256 => uint256)) public usedLimit;

  //total mint limit for each minter for a particular token
  mapping(address => mapping(uint256 => uint256)) mintTotalLimit;

  //maps a token id to its category e.g weapon,character etc
  mapping(uint256 => string) public idToCategory;

  //Set the limits for a particular token ID
  mapping(uint256 => uint256) public tokenIdLimits;

  //Track supply per tokenId
  mapping(uint256 => uint256) public supplyPerId;

  //An array of all item types available
  string[] allItemTypes;

  //An array of all item Ids available
  uint256[] allIds;

  //Allow a minter to increase the limit of a tokenId mint
  function increaseLimit(uint256 _tokenId, uint256 _newLimit)
    public
    onlyRole(MINTER)
  {
    {
      require(
        bytes(idToCategory[_tokenId]).length > 0,
        "item already does not exist"
      );
      require(
        _newLimit > tokenIdLimits[_tokenId],
        "new Limit must be greater than existing limit"
      );
      tokenIdLimits[_tokenId] = _newLimit;
    }
  }

  //increase how many times a minter can mint a particular token
  function increaseMinterLimit(
    address _minter,
    uint256 _tokenId,
    uint256 _newLimit
  ) public onlyRole(getRoleAdmin(MINTER)) {
    require(_roles[MINTER].members[_minter], "Address is not a minter");
    require(
      _newLimit > mintTotalLimit[_minter][_tokenId],
      "New limit must be greater "
    );
    mintTotalLimit[_minter][_tokenId] = _newLimit;
  }

  //Add a new category for a token , especially while trying to mint a new token for the first time
  function addNewItemCategory(uint256 _itemId, string memory _category)
    public
    onlyRole(getRoleAdmin(MINTER))
  {
    require(
      bytes(idToCategory[_itemId]).length == 0,
      "item already has a category"
    );
    idToCategory[_itemId] = _category;
    if (!categoryExists[_category]) {
      allItemTypes.push(_category);
      categoryExists[_category] = true;
    }
    //No need to check for duplication
    allIds.push(_itemId);
  }

  //Check how many tokens exist for a specific tokenId
  function checkExisting(uint256 _tokenId)
    public
    view
    returns (uint256 currentSupply_)
  {
    currentSupply_ = supplyPerId[_tokenId];
  }

  //Used to conform with generic platfform naming
  function name() public pure returns (string memory) {
    return "Keres";
  }

  //Set the new root directory for img data
  function setNewBaseUri(string memory _newBaseUri)
    public
    onlyRole(getRoleAdmin(MINTER))
  {
    _setURI(_newBaseUri);
  }

  //Allow the overlord to grant the role of minter to an account
  function grantRole(address account)
    public
    onlyRole(getRoleAdmin(DEFAULT_ADMIN_ROLE))
  {
    _grantRole(MINTER, account);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(AccessControl, ERC1155)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function mintTo(
    address _recipient,
    uint256 _itemId,
    uint256 _quantity
  ) public onlyRole(MINTER) {
    require(
      bytes(idToCategory[_itemId]).length > 0,
      "item does not have a category yet"
    );

    require(
      checkExisting(_itemId) < tokenIdLimits[_itemId],
      "Minting limit for this item has been reached"
    );
    require(
      mintTotalLimit[_msgSender()][_itemId] -
        usedLimit[_msgSender()][_itemId] >=
        _quantity,
      "You have reached your minting limit for this item"
    );
    usedLimit[_msgSender()][_itemId] += _quantity;
    supplyPerId[_itemId] += _quantity;
    //If receving address is a contract, it must implement  {ERC721Receiver.onERC721OnReceived()}
    _mint(_recipient, _itemId, _quantity, "");
    exists[_itemId] = true;
  }

  function mintBatchTo(
    address _recipient,
    uint256[] calldata _itemIds,
    uint256[] calldata _quantities
  ) external onlyRole(MINTER) {
    require(
      _itemIds.length == _quantities.length,
      "Length of arrays should be the same"
    );
    for (uint256 i; i < _itemIds.length; i++) {
      require(
        bytes(idToCategory[_itemIds[i]]).length > 0,
        "item does not have a category yet"
      );
      require(
        checkExisting(_itemIds[i]) < tokenIdLimits[_itemIds[i]],
        "Minting limit for this item has been reached"
      );
      require(
        mintTotalLimit[_msgSender()][_itemIds[i]] -
          usedLimit[_msgSender()][_itemIds[i]] >=
          _quantities[i],
        "You have reached your minting limit for this item"
      );
      usedLimit[_msgSender()][_itemIds[i]] += _quantities[i];
      supplyPerId[_itemIds[i]] += _quantities[i];
      exists[_itemIds[i]] = true;
    }
    //If receving address is a contract, it must implement  {ERC721Receiver.onERC721BatchReceived()}
    _mintBatch(_recipient, _itemIds, _quantities, "");
  }

  struct AllItemReturns {
    uint256 id;
    string category;
    uint256 currentTotalSupply;
  }

  //returns comprehensive info about all tokens minted till date
  function checkAllItems()
    public
    view
    returns (AllItemReturns[] memory items_)
  {
    items_ = new AllItemReturns[](allIds.length);
    for (uint256 j; j < allIds.length; j++) {
      items_[j].id = allIds[j];
      items_[j].category = idToCategory[allIds[j]];
      items_[j].currentTotalSupply = supplyPerId[allIds[j]];
    }
  }

  //hope this works

  function uri(uint256 _itemId) public view override returns (string memory) {
    string memory _category = idToCategory[_itemId];
    string memory link = string(abi.encodePacked(_uri, _category, "/"));
    return strWithUint(link, _itemId);
  }

  function strWithUint(string memory _str, uint256 value)
    internal
    pure
    returns (string memory)
  {
    // Inspired by OraclizeAPI's implementation - MIT licence
    // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol
    bytes memory buffer;
    unchecked {
      if (value == 0) {
        return string(abi.encodePacked(_str, "0"));
      }
      uint256 temp = value;
      uint256 digits;
      while (temp != 0) {
        digits++;
        temp /= 10;
      }
      buffer = new bytes(digits);
      uint256 index = digits - 1;
      temp = value;
      while (temp != 0) {
        buffer[index--] = bytes1(uint8(48 + (temp % 10)));
        temp /= 10;
      }
    }
    return string(abi.encodePacked(_str, buffer));
  }
}
