// SPDX-License-Identifier: UNLICENSED
// Author: Temisan Momodu
pragma solidity ^0.8.13;
import {PriceConverter} from "./PriceConverter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// Custom error for ownership check
error FundMe__NotOwner();

contract FundMe {
    using PriceConverter for uint256;

    // Chainlink Price Feed Interface
    AggregatorV3Interface private s_priceFeed;
    uint256 public constant MINIMUM_USD = 5e18;
    address[] private s_funders;
    mapping(address => uint256) private s_addressToAmountFunded;
    address private immutable i_owner;
    event PriceReceived(int256 price);

    // Contract constructor
    constructor(address priceFeed) {
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    // Function to allow users to fund the contract
    function fund() public payable {
        // Ensure the sent amount meets the minimum USD requirement
        require(
            msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
            "Insufficient funds sent"
        );

        // Record the funder's address and the funded amount
        s_addressToAmountFunded[msg.sender] += msg.value;
        s_funders.push(msg.sender);
    }

    // Function for the owner to withdraw funds
    function withdraw() public onlyOwner {
        // Reset amounts funded by each funder
        for (
            uint256 funderIndex = 0;
            funderIndex < s_funders.length;
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }

        // Reset the s_funders array
        s_funders = new address[](0);

        // Transfer the contract balance to the owner
        (bool success, ) = i_owner.call{value: address(this).balance}("");
        require(success);
    }

    function cheaperWithdraw() public onlyOwner {
        uint256 fundersLength = s_funders.length;

        for (
            uint256 funderIndex = 0;
            funderIndex < fundersLength;
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }

        s_funders = new address[](0);

        // Transfer the contract balance to the owner
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(callSuccess, "call failed");
    }

    // Function to log the latest price from the Chainlink Price Feed
    function logPrice() public {
        (, int256 price, , , ) = s_priceFeed.latestRoundData();

        // Log the received price for debugging
        emit PriceReceived(price);

        // Ensure the price is not negative (sanity check)
        require(price >= 0, "Negative price not supported");
    }

    // Function to get the version of the Chainlink Price Feed
    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }

    // Modifier to check if the sender is the owner
    modifier onlyOwner() {
        require(msg.sender == i_owner, "Not the owner");
        _;
    }

    //recieve() fallback();

    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }

    /**
     * view /pure function (Getters)
     * check if the funding has been populated
     */

    function getAddressToAmountFunded(
        address fundingAddress
    ) external view returns (uint256) {
        return s_addressToAmountFunded[fundingAddress];
    }

    function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }
}
