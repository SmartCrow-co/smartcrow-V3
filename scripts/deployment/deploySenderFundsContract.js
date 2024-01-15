const hre = require("hardhat")

async function deploySenderFundsContract(chainId) {
    try {
        // Get the ContractFactory of your SenderFundsContract
        const SenderFundsContract = await hre.ethers.getContractFactory("SenderFundsContract");
    
        // Deploy the contract
        const contract = await SenderFundsContract.deploy();
    
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
