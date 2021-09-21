pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TIM is ERC1155 {
  constructor(string memory u) ERC1155(u) {
    _mint(_msgSender(), 0, 500, "");
  }
}
