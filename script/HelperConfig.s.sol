// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;
    uint8 constant DECIMALS = 8;
    int256 constant INITIAL_PRICE = 2000e8;
    struct NetworkConfig {
        address priceFeed; // Network Price Feed Addresses
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getEthMainnetConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        //Price Feed
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        });
        return sepoliaConfig;
    }

    function getEthMainnetConfig() public pure returns (NetworkConfig memory) {
        //Price Feed
        NetworkConfig memory ethConfig = NetworkConfig({
            priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        });
        return ethConfig;
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig;
        }
        //Deploy Mock
        MockV3Aggregator anvilEthConfig = new MockV3Aggregator(
            DECIMALS,
            INITIAL_PRICE
        );
        //Price Feed
        NetworkConfig memory anvilEth = NetworkConfig({
            priceFeed: address(anvilEthConfig)
        });
        return anvilEth;
    }
}
