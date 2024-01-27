const hre = require("hardhat")

async function deploySenderFundsContract(chainId) {
    try {
        // Get the ContractFactory of your SenderFundsContract
        const SenderFundsContract = await hre.ethers.getContractFactory("SenderFundsContract");
    
        // Deploy the contract
        const contract = await SenderFundsContract.deploy(
          "0x79c950c7446b234a6ad53b908fbf342b01c4d446", // Goerli USDT Token
          "0x79c950c7446b234a6ad53b908fbf342b01c4d446", // Goerli USDC Token 
          "0x79c950c7446b234a6ad53b908fbf342b01c4d446", // Goerli WBTC Token
          "0x2899a03ffDab5C90BADc5920b4f53B0884EB13cC", // Goerli DAI Token
          "0x79c950c7446b234a6ad53b908fbf342b01c4d446"  // Goerli WETH Token
        );
    
        // Wait for the deployment transaction to be mined
        await contract.deployed();
    
        console.log(`SenderFundsContract deployed to: ${contract.address}`);
      } catch (error) {
        console.error(error);
        process.exit(1);
      }
}

module.exports = {
    deploySenderFundsContract,
}
