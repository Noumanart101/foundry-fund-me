// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";

contract FundMeTest is ZkSyncChainChecker, StdCheats, CodeConstants, Test {
    FundMe fundMe;
    HelperConfig helperConfig;

    address USER = makeAddr("user");
    uint256 constant INITIAL_BALANCE = 10 ether;
    uint256 constant SEND_VALUE = 0.01 ether;

    function setUp() external {
        if (!isZkSyncChain()) {
            DeployFundMe deployer = new DeployFundMe();
            (fundMe, helperConfig) = deployer.deployFundMe();
        } else {
            MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
                DECIMALS,
                INITIAL_PRICE
            );
            fundMe = new FundMe(address(mockPriceFeed));
        }
        vm.deal(USER, INITIAL_BALANCE);
    }

    function testPriceFeedSetCorrectly() public skipZkSync {
        address retrievedPriceFeed = address(fundMe.getPriceFeed());
        address expectedPriceFeed = helperConfig
            .getNetworkConfigByChainId(block.chainid)
            .priceFeed;
        assertEq(expectedPriceFeed, retrievedPriceFeed);
    }

    function testMinimumUsdIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testMsgSenderIsOwner() public view {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
        assertEq(fundMe.getVersion(), 4);
    }

    function testRevertSendNotEnoughEth() public skipZkSync {
        vm.expectRevert();
        fundMe.fund();
    }

    function testFundUpdatesFundersDataStructure() public skipZkSync {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        assertEq(fundMe.getFunder(0), USER);
        assertEq(fundMe.getAddressToAmountFunded(USER), SEND_VALUE);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        assert(address(fundMe).balance > 0);
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded skipZkSync {
        vm.expectRevert();
        vm.prank(address(4));
        fundMe.withdraw();
    }

    function testWithdrawWithSingleFunder() public funded skipZkSync {
        //Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;
        //Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();
        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingOwnerBalance + startingFundMeBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawWithMultipleFunders() public funded skipZkSync {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 2;
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), INITIAL_BALANCE);
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;
        // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();
        // Assert
        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );

        // assert(
        //     (numberOfFunders + 1) * SEND_VALUE ==
        //         fundMe.getOwner().balance - startingOwnerBalance
        // );
    }
}
