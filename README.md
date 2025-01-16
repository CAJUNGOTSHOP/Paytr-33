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