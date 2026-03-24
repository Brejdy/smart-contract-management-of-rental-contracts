# Rental Agreement DApp (Hardhat + Frontend)

A demo project for a smart rental agreement with:
- rent and deposit payments in `ETH` or `stablecoin (mUSDC)`,
- `landlord / tenant / arbiter` roles,
- stablecoin auto-payments (manual trigger),
- a simple web UI for interaction.

## 1. Requirements

- Node.js 18+ (LTS recommended)
- npm
- MetaMask browser extension

## 2. Installation

From the project root:

```bash
npm install
```

## 3. Quick Start (Live Demo Flow)

Use 3 terminals.

### Terminal A: local blockchain

```bash
npx hardhat node
```

Keep it running during the whole demo.

### Terminal B: deploy contracts + export ABI for frontend

```bash
npx hardhat run scripts/deployRental.js --network localhost
```

This deploys:
- `MockV3Aggregator` (ETH/USD feed),
- `MockERC20` (mUSDC),
- 2x `RentalAgreement`:
  - `ETH` mode,
  - `stablecoin` mode.

It also updates files in `frontend/abi`:
- `RentalAgreement.abi.json`
- `RentalAgreement.addresses.json`
- `MockERC20.address.json`
- `MockV3Aggregator.address.json`

### Terminal C: frontend

Run a static HTTP server in `frontend` (required because the UI uses `fetch()` for ABI files).

Option 1 (Node):
```bash
npx serve frontend -l 3000
```

Option 2 (Python):
```bash
cd frontend
python -m http.server 5500
```

Open:
- `http://127.0.0.1:5500/index.html` (new contract)
- `http://127.0.0.1:5500/contracts.html` (existing contracts)

## 4. MetaMask Setup for Demo

### Network

- Network Name: `Hardhat Local`
- RPC URL: `http://127.0.0.1:8545`
- Chain ID: `31337`
- Currency Symbol: `ETH`

### Accounts (roles)

The deploy script uses these signers:
- index `0` = `landlord` (contract owner),
- index `1` = `tenant`,
- index `2` = `arbiter`.

Import private keys from the `npx hardhat node` output (Terminal A) into MetaMask.

## 5. Recommended Presentation Scenario

1. Start node, deploy, and frontend.
2. Open `contracts.html`.
3. Load contract addresses from `frontend/abi/RentalAgreement.addresses.json`:
   - first `eth`,
   - then `stable`.
4. Switch MetaMask accounts and show role-based actions:
   - tenant: `Pay deposit`, `Pay rent`, `Authorize/Revoke auto-payment`,
   - landlord: `Request warning`, `Confirm warning`, `Process auto payment` (stablecoin only),
   - arbiter: deduction request approval/rejection.

## 6. Useful Commands

Compile:
```bash
npx hardhat compile
```

Redeploy:
```bash
npx hardhat run scripts/deployRental.js --network localhost
```

## 7. Common Issues

- `This contract is only available on Hardhat localhost (chainId = 31337).`
  - Wrong MetaMask network. Switch to local Hardhat (`31337`).

- Frontend cannot load ABI/addresses (`fetch` error / 404):
  - Do not open HTML via `file://`.
  - Run an HTTP server in `frontend`.
  - After each redeploy, confirm JSON files in `frontend/abi` were updated.

- Stablecoin transactions fail with `allowance` error:
  - Tenant must call `Set allowance` first.

## 8. Project Structure

- `contracts/` - Solidity contracts
- `scripts/deployRental.js` - deploy + export ABI/addresses for frontend
- `frontend/` - static web UI
- `frontend/abi/` - ABI and contract address files for UI

## 9. Start full project
 - npm run dev - step 3 is not required
