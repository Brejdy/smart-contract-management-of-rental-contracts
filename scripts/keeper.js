const fs = require("fs");
const path = require("path");
const hre = require("hardhat");

function parseArg(name) {
  const prefix = `--${name}=`;
  const arg = process.argv.find((item) => item.startsWith(prefix));
  return arg ? arg.slice(prefix.length) : undefined;
}

function loadStableAddress() {
  const addressesPath = path.join(__dirname, "../frontend/abi/RentalAgreement.addresses.json");
  const addresses = JSON.parse(fs.readFileSync(addressesPath, "utf8"));
  return addresses.stable;
}

function stamp() {
  return new Date().toISOString();
}

async function main() {
  const intervalMs = Number(process.env.KEEPER_INTERVAL_MS || parseArg("intervalMs") || 15000);
  const signerIndex = Number(process.env.KEEPER_SIGNER_INDEX || parseArg("signerIndex") || 0);
  const addressFromArg = process.env.RENTAL_ADDRESS || parseArg("address");

  if (!Number.isFinite(intervalMs) || intervalMs < 1000) {
    throw new Error("Invalid interval. Use at least 1000 ms.");
  }

  const signers = await hre.ethers.getSigners();
  if (signerIndex < 0 || signerIndex >= signers.length) {
    throw new Error(`Invalid signer index ${signerIndex}. Available signers: 0..${signers.length - 1}`);
  }

  const keeperSigner = signers[signerIndex];
  const rentalAddress = addressFromArg || loadStableAddress();
  if (!rentalAddress) {
    throw new Error("Stable rental agreement address not found.");
  }

  const rentalArtifact = await hre.artifacts.readArtifact("contracts/RentalAgreement.sol:RentalAgreement");
  const rentalAbi = rentalArtifact.abi;
  const rental = new hre.ethers.Contract(rentalAddress, rentalAbi, keeperSigner);

  const isStablecoinPayment = await rental.isStabelcoinPayment();
  if (!isStablecoinPayment) {
    throw new Error("Keeper supports only stablecoin rental contracts.");
  }

  let running = false;
  let timer;

  const tick = async () => {
    if (running) return;
    running = true;

    try {
      const [approved, dueNow, ready, periodKey, nextDueTimestamp, allowance] = await rental.getAutoPaymentStatus();

      if (!approved) {
        console.log(`[${stamp()}] Auto-payment not approved yet.`);
        return;
      }

      if (!dueNow) {
        console.log(
          `[${stamp()}] Payment not due yet. nextDue=${new Date(Number(nextDueTimestamp) * 1000).toISOString()}`
        );
        return;
      }

      if (!ready) {
        console.log(
          `[${stamp()}] Payment due, but not ready. allowance=${allowance.toString()} rent=${(await rental.rentAmount()).toString()}`
        );
        return;
      }

      console.log(`[${stamp()}] Auto-payment due for period=${periodKey.toString()}. Sending transaction...`);
      const tx = await rental.processAutoPayment();
      const receipt = await tx.wait();
      console.log(`[${stamp()}] Auto-payment processed. tx=${receipt.hash}`);
    } catch (err) {
      console.error(`[${stamp()}] Keeper tick failed: ${err.message}`);
    } finally {
      running = false;
    }
  };

  console.log(`[${stamp()}] Stablecoin keeper started`);
  console.log(`network=${hre.network.name} address=${rentalAddress}`);
  console.log(`signer=${keeperSigner.address} intervalMs=${intervalMs}`);

  await tick();
  timer = setInterval(tick, intervalMs);

  const shutdown = (signal) => {
    clearInterval(timer);
    console.log(`[${stamp()}] ${signal} received. Keeper stopped.`);
    process.exit(0);
  };

  process.on("SIGINT", () => shutdown("SIGINT"));
  process.on("SIGTERM", () => shutdown("SIGTERM"));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
