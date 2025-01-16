Install the necessary dependencies with `forge install`.

You will need to run the tests on a Sepolia fork by using this command:
`forge test --fork-url https://sepolia.infura.io/v3/YOURKEY` or
`forge test --fork-url https://eth-sepolia.g.alchemy.com/v2/YOURKEY`

## Frequently Asked Questions (FAQ)

### How do I install the Forge Standard Library?

To install the Forge Standard Library, you can use the `forge install` command. Here are the steps to follow:

* Open your terminal or command prompt.
* Navigate to the root directory of your project.
* Run the following command:
  ```bash
  forge install foundry-rs/forge-std
  ```

### How do I replace `YOURKEY` with the actual Infura project key?

To replace `YOURKEY` with your actual Infura project key, follow these steps:

* Open the file where the `YOURKEY` placeholder is located.
* Replace `YOURKEY` with your actual Infura project key.

### How do I unlock the account `0x7713974908Be4BEd47172370115e8b1219F4A5f0` in the wallet?

To unlock the account `0x7713974908Be4BEd47172370115e8b1219F4A5f0` in your wallet, follow these steps:

* Open your wallet application.
* Navigate to the account management section.
* Find the account with the address `0x7713974908Be4BEd47172370115e8b1219F4A5f0`.
* Follow the instructions provided by your wallet application to unlock the account.

### How do I update the `foundry.toml` file with the `fork_url`?

To update the `foundry.toml` file with the `fork_url`, follow these steps:

* Open the `foundry.toml` file in a text editor.
* Locate the `[profile.sepolia]` section.
* Replace the `fork_url` value with the correct Infura API key.
* Save the changes to the `foundry.toml` file.
