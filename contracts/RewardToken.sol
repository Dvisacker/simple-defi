// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RewardToken is ERC20 {
    constructor() ERC20("Staking Token", "RWD") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}
