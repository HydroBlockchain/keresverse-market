pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MarketPlace is ERC1155Holder {
  struct SellOrder {
    IERC1155 token;
    //IERC20 erc20;
    uint256 tokenAmount;
    uint256 weiAmount;
    uint256 timeListed;
    uint256 deadline;
    uint256 tokenCount;
    uint256 id;
    address owner;
    bool fulfilled;
    bool weiList;
    bool available;
  }

  mapping(uint256 => SellOrder) allOrders;

  uint256 orderCounter = 0;
  IERC20 stToken;

  constructor(IERC20 _token) {
    stToken = _token;
  }

  modifier onlySaleLister(uint256 _orderId) {
    require(
      msg.sender == allOrders[_orderId].owner,
      "You are not the order owner"
    );
    _;
  }

  modifier onlyAvailable(uint256 _orderId) {
    require(allOrders[_orderId].available, "Order not available for sale");
    _;
  }

  function setSaleOrder(
    address _token,
    uint256 _tokenId,
    uint256 _tokenCount,
    bool _weiList,
    uint256 _weiPrice,
    uint256 _tokenPrice,
    uint8 _days
  ) external {
    require(
      IERC1155(_token).balanceOf(msg.sender, _tokenId) >= _tokenCount,
      "You do not have that much tokens to sell"
    );

    SellOrder storage s = allOrders[orderCounter];
    require(
      IERC1155(_token).isApprovedForAll(msg.sender, address(this)),
      "Should approve this contract as an operator first"
    );
    s.token = IERC1155(_token);
    s.timeListed = block.timestamp;
    s.deadline = block.timestamp + (_days * 1 days);
    s.tokenCount = _tokenCount;
    s.id = _tokenId;
    s.owner = msg.sender;
    if (_weiList) {
      require(_tokenPrice == 0, "Token price should be 0");
      require(_weiPrice > 0, "Wei Price should be greater than 0");
      s.weiAmount = _weiPrice;
    }
    if (!_weiList) {
      require(_weiPrice == 0, "Wei Price should be 0");
      require(_tokenPrice > 0, "Token price should be greater than 0");
      s.tokenAmount = _tokenPrice;
    }
    s.weiList = _weiList;
    s.available = true;
    orderCounter++;
  }

  function fulfillOrder(uint256 _orderId) external payable {
    SellOrder storage s = allOrders[_orderId];
    require(!s.fulfilled, "Order has been fulfilled");
    require(s.available, "Order not available");
    require(
      s.token.isApprovedForAll(s.owner, address(this)),
      "Should approve this contract as an operator first"
    );
    require(
      s.token.balanceOf(s.owner, s.id) >= s.tokenCount,
      "Owner should have greater than or equal tokens"
    );
    if (s.weiList) {
      require(
        msg.value == s.weiAmount,
        "Sent Amount is not equal to token amount"
      );
      payable(s.owner).transfer(s.weiAmount);
      s.token.safeTransferFrom(s.owner, msg.sender, s.id, s.tokenCount, "");
    }
    if (!s.weiList) {
      require(
        stToken.allowance(msg.sender, address(this)) >= s.tokenAmount,
        "you have approve the token first"
      );
      require(stToken.transferFrom(msg.sender, s.owner, s.tokenAmount));
      s.token.safeTransferFrom(s.owner, msg.sender, s.id, s.tokenCount, "");
    }
    s.fulfilled = true;
    s.available = false;
  }

  function checkOrder(uint256 _orderId) public view returns (SellOrder memory) {
    return allOrders[_orderId];
  }

  function changeOrderPrice(
    uint256 _orderId,
    uint256 _newWeiPrice,
    uint256 _newTokenPrice
  ) public onlySaleLister(_orderId) {
    require(!allOrders[_orderId].fulfilled, "Order already fulfilled");
    if (allOrders[_orderId].weiList) {
      allOrders[_orderId].weiAmount = _newWeiPrice;
    }
    if (!allOrders[_orderId].weiList) {
      allOrders[_orderId].tokenAmount = _newTokenPrice;
    }
  }

  function cancelOrder(uint256 _orderId) public onlySaleLister(_orderId) {
    allOrders[_orderId].available = false;
  }
}
