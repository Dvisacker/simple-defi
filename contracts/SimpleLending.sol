// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Lending is Ownable, ReentrancyGuard {
    address[] public tokens;
    mapping(address => address) public tokenToPriceFeed;

    mapping(address => mapping(address => uint256)) public userBorrows;
    mapping(address => mapping(address => uint256)) public userDeposits;

    uint8 liquidationThreshold = 80; // user must have 80% of the borrowed value as collateral
    uint8 liquidationPenalty = 5; // 5% penalty for liquidation

    constructor() Ownable(msg.sender) {}

    function deposit(address _token, uint256 _amount) public {
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        userDeposits[msg.sender][_token] += _amount;
    }

    function withdraw(address _token, uint256 _amount) public {
        require(userDeposits[msg.sender][_token] >= _amount, "Insufficient balance");
        IERC20(_token).transfer(msg.sender, _amount);
        userDeposits[msg.sender][_token] -= _amount;
    }

    function borrow(address _token, uint256 _amount) public {
        require(userDeposits[msg.sender][_token] >= _amount, "Insufficient collateral");
        userBorrows[msg.sender][_token] += _amount;
    }

    function repay(address _user, address _token, uint256 _amount) public {
        require(userBorrows[_user][_token] >= _amount, "Insufficient borrow balance");
        IERC20(_token).transferFrom(_user, address(this), _amount);
        userBorrows[_user][_token] -= _amount;
    }

    function liquidate(address _user, address _collateralToken, uint256 _borrowedTokenAmount, address _borrowedToken)
        public
    {
        // Check if the user's health factor is below the threshold
        require(healthFactor(_user) < liquidationThreshold, "Health factor is above the threshold");
        require(userBorrows[_user][_borrowedToken] > 0, "No borrow balance to liquidate");
        require(userDeposits[_user][_collateralToken] > 0, "No collateral to liquidate");

        uint256 borrowValue = getEthValue(_borrowedTokenAmount, _borrowedToken);
        uint256 collateralAmount =
            getTokenValueFromEth(_collateralToken, borrowValue) * (100 + liquidationPenalty) / 100;

        require(userDeposits[_user][_collateralToken] >= collateralAmount, "");

        IERC20(_collateralToken).transfer(_user, collateralAmount);
        IERC20(_borrowedToken).transferFrom(_user, address(this), _borrowedTokenAmount);
        userBorrows[_user][_borrowedToken] -= _borrowedTokenAmount;
    }

    function getAccountInformation(address _user) public view returns (uint256, uint256) {
        uint256 depositValue = getAccountCollateralValue(_user);
        uint256 borrowValue = getAccountBorrowedValue(_user);
        return (depositValue, borrowValue);
    }

    function getAccountCollateralValue(address _user) public view returns (uint256) {
        uint256 totalCollateralValue = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            totalCollateralValue += getEthValue(userDeposits[_user][tokens[i]], tokens[i]);
        }

        return totalCollateralValue;
    }

    function getAccountBorrowedValue(address _user) public view returns (uint256) {
        uint256 totalBorrowedValue = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            totalBorrowedValue += getEthValue(userBorrows[_user][tokens[i]], tokens[i]);
        }

        return totalBorrowedValue;
    }

    // returns the health with 18 decimals
    function healthFactor(address _user) public view returns (uint256) {
        uint256 collateralValue = getAccountCollateralValue(_user);
        uint256 borrowedValue = getAccountBorrowedValue(_user);
        uint256 numerator = collateralValue * liquidationThreshold * 1e18;
        uint256 denominator = borrowedValue * 100;
        return numerator / denominator;
    }

    function getEthValue(uint256 _amount, address _token) public view returns (uint256) {
        address priceFeedAddress = tokenToPriceFeed[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return _amount * uint256(price);
    }

    function getTokenValueFromEth(address token, uint256 amount) public view returns (uint256) {
        address priceFeedAddress = tokenToPriceFeed[token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeedAddress);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (amount * 1e18) / uint256(price);
    }

    function addToken(address _token, address _priceFeed) public onlyOwner {
        tokens.push(_token);
        tokenToPriceFeed[_token] = _priceFeed;
    }
}
