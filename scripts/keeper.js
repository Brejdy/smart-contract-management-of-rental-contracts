const fs = require("fs");
const path = require("path");
const hre = require("hardhat");

function parseArg(name) {
  const prefix = `--${name}=`;
  const arg = process.argv.find((a) => a.startsWith(prefix));
  return arg ? arg.slice(prefix.length) : undefined;
}

function loadAddressFromFile(mode) {
  const addressesPath = path.join(__dirname, "../frontend/abi/RentalAgreement.addresses.json");
  const addresses = JSON.parse(fs.readFileSync(addressesPath, "utf8"));
  return mode === "stable" ? addresses.stable : addresses.eth;
}

async function main() {
  const mode = (process.env.RENTAL_MODE || parseArg("mode") || "eth").toLowerCase();
  const intervalMs = Number(process.env.KEEPER_INTERVAL_MS || parseArg("intervalMs") || 15000);
  const signerIndex = Number(process.env.KEEPER_SIGNER_INDEX || parseArg("signerIndex") || 0);
  const addressFromArg = process.env.RENTAL_ADDRESS || parseArg("address");

  if (!["eth", "stable"].includes(mode)) {
    throw new Error("Invalid mode. Use 'eth' or 'stable'.");
  }
  if (!Number.isFinite(intervalMs) || intervalMs < 1000) {
    throw new Error("Invalid interval. Use at least 1000 ms.");
  }

  const signers = await hre.ethers.getSigners();
  if (signerIndex < 0 || signerIndex >= signers.length) {
    throw new Error(`Invalid signer index ${signerIndex}. Available signers: 0..${signers.length - 1}`);
  }
  const keeperSigner = signers[signerIndex];

  const rentalAddress = addressFromArg || loadAddressFromFile(mode);
  if (!rentalAddress) {
    throw new Error("Rental agreement address not found.");
  }

  const abiPath = path.join(__dirname, "../frontend/abi/RentalAgreement.abi.json");
  const rentalAbi = JSON.parse(fs.readFileSync(abiPath, "utf8"));
  const rental = new hre.ethers.Contract(rentalAddress, rentalAbi, keeperSigner);

  let running = false;
  let timer;

  const stamp = () => new Date().toISOString();

  const tick = async () => {
    if (running) return;
    running = true;

    try {
      const [upkeepNeeded, performData] = await rental.checkUpkeep("0x");
      if (!upkeepNeeded) {
        console.log(`[${stamp()}] No upkeep needed.`);
        return;
      }

      console.log(`[${stamp()}] Upkeep needed. Sending performUpkeep...`);
      const tx = await rental.performUpkeep(performData);
      const receipt = await tx.wait();
      console.log(`[${stamp()}] Upkeep executed. tx=${receipt.hash}`);
    } catch (err) {
      console.error(`[${stamp()}] Keeper tick failed: ${err.message}`);
    } finally {
      running = false;
    }
  };

  console.log(`[${stamp()}] Keeper started`);
  console.log(`network=${hre.network.name} mode=${mode} address=${rentalAddress}`);
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
