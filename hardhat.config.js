import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-verify";

/** @type {import('hardhat/config').HardhatUserConfig} */
export default {
  solidity: {
    version: "0.8.24",
    settings: {
      evmVersion: "cancun",
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    bittensorTestnet: {
      url: "https://api-bittensor-testnet.n.dwellir.com/514a23e2-83e4-4212-8388-1979709224b6",
      chainId: 945,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    bittensorMainnet: {
      url: "https://api-bittensor-mainnet.n.dwellir.com/514a23e2-83e4-4212-8388-1979709224b6",
      chainId: 964,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: {
      bittensorMainnet: "no-api-key-needed",
    },
    customChains: [
      {
        network: "bittensorMainnet",
        chainId: 964,
        urls: {
          apiURL: "https://evm.taostats.io/api",
          browserURL: "https://evm.taostats.io",
        },
      },
    ],
  },
};
