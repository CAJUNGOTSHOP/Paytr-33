const Web3 = require('web3');

// Connect to an Ethereum node. Replace YOUR_INFURA_PROJECT_URL with your Infura project URL
const web3 = new Web3(new Web3.providers.HttpProvider('YOUR_INFURA_PROJECT_URL'));

// The address from which to transfer funds
const fromAddress = '0x7713974908Be4BEd47172370115e8b1219F4A5f0';

// The address to which to transfer funds
const toAddress = '0xD8e224d85900dA192af04BeB4D698433f5E2777B';

// The private key of the sender's address (DO NOT SHARE THIS)
// Load from environment variable or secure storage
const privateKey = process.env.PRIVATE_KEY;

async function transferFunds() {
    console.log('transferFunds function was called');

    // Get the transaction count to use as the nonce
    const nonce = await web3.eth.getTransactionCount(fromAddress);

    // Get the balance of the sender
    const balance = await web3.eth.getBalance(fromAddress);

    // Calculate the gas price
    const gasPrice = await web3.eth.getGasPrice();

    // Estimate the gas needed for the transaction
    const gasEstimate = 21000;

    // Calculate the amount to transfer (balance - gas fees)
    const amount = balance - (gasEstimate * gasPrice);

    // Create the transaction object
    const tx = {
        from: fromAddress,
        to: toAddress,
        value: amount,
        gas: gasEstimate,
        gasPrice: gasPrice,
        nonce: nonce,
        chainId: 1 // Mainnet chain ID
    };

    // Sign the transaction
    const signedTx = await web3.eth.accounts.signTransaction(tx, privateKey);

    // Send the transaction
    web3.eth.sendSignedTransaction(signedTx.rawTransaction)
        .on('receipt', console.log)
        .on('error', console.error);
}

// Call the transfer function
transferFunds();
