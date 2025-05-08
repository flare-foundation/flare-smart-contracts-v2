// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {

    uint8 immutable internal __decimals;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol) {
        __decimals = _decimals;
    }

    function mintAmount(address _target, uint256 amount) public {
        _mint(_target, amount);
    }

    function burnAmount(address _target, uint256 amount) public {
        _burn(_target, amount);
    }

    function decimals() public view override returns (uint8) {
        return __decimals;
    }
}
