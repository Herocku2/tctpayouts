# tctpayouts
Smart contract of payouts
TctPayouts Smart Contract

Overview

The PayoutsTCT smart contract is designed to facilitate secure and efficient bulk payouts using TCT and USDT tokens. It allows for mass token distribution while implementing security features such as pause, lock, and ownership transfer.

Features

✅ Bulk Token Distribution – Efficiently send payments to multiple recipients in a single transaction.✅ Supports ERC-20 Tokens – Works with TCT and USDT tokens.✅ Security Controls – Includes pausing and locking mechanisms to prevent unauthorized transactions.✅ Ownership Management – Allows safe transfer of ownership to another address.✅ Gas Optimization – Limits batch sizes for efficient transaction processing.

Contract Functions

🔹 Administrative Functions

pause() / unpause() – Allows the contract owner to pause or resume transactions.

transferOwnership(address newOwner) – Transfers contract ownership to a new admin.

setPendingOwner(address newOwner) – Sets a pending owner for approval.

🔹 Token Distribution

distributeTokens(address token, address[] memory recipients, uint256[] memory amounts) – Sends tokens to multiple recipients in a single transaction (limited by MAX_BATCH_SIZE).

🔹 Security Features

_locked – Prevents reentrant calls to critical functions.

_paused – Restricts all operations when activated by the owner.

How It Works

The contract owner initializes the TCT and USDT token addresses.

Admin can pause/unpause transactions as needed.

Users receive bulk payments using the distributeTokens function.

The contract ensures gas efficiency and security using batch size limits and access control.

Security Considerations

🔹 Reentrancy Protection – Ensures that functions cannot be exploited for multiple withdrawals.🔹 Ownership Transfer Validation – Prevents unauthorized ownership changes.🔹 Paused State Protection – Transactions are blocked when paused, preventing misuse.

License

This project is released under the MIT License.


