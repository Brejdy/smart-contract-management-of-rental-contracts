// scripts/deployRental.js
const fs = require("fs");
const path = require("path");
const hre = require("hardhat");

async function main() {
  const [landlord, tenant, arbiter] = await hre.ethers.getSigners();

  // DateUtils – jen deploy, nic nelinkujeme (vše internal)
  const DateUtils = await hre.ethers.getContractFactory("DateUtils");
  const dateUtils = await DateUtils.deploy();
  await dateUtils.waitForDeployment();
  console.log(`DateUtils deployed to: ${await dateUtils.getAddress()}`);

  // Mock price feed
  const MockV3Aggregator = await hre.ethers.getContractFactory("MockV3Aggregator");
  const DECIMALS = 8;
  const INITIAL_ANSWER = hre.ethers.parseUnits("2000", DECIMALS);
  const mockFeed = await MockV3Aggregator.deploy(DECIMALS, INITIAL_ANSWER);
  await mockFeed.waitForDeployment();
  console.log(`MockV3Aggregator deployed to: ${await mockFeed.getAddress()}`);

  // RentalAgreement (bez libraries; DateUtils je internal)
  const RentalAgreementFactory = await hre.ethers.getContractFactory("RentalAgreement");

  // Testovací hodnoty
  const rentAmount = hre.ethers.parseEther("1");
  const depositAmount = hre.ethers.parseEther("0.5");
  const contractIPFSHash = "QmSomeIPFSHash";
  const isStablecoinPayment = false;
  const stablecoinAddress = "0x0000000000000000000000000000000000000000";
  const priceFeedAddress = await mockFeed.getAddress();
  const paymentDueDate = 5;

  console.log("DEPLOY ARGS CHECK", {
    tenant: tenant.address,
    arbiter: arbiter.address,
    rentAmount: rentAmount.toString(),
    depositAmount: depositAmount.toString(),
    contractIPFSHash,
    isStablecoinPayment,
    stablecoinAddress,
    priceFeedAddress,
    paymentDueDate
  });

  const rentalAgreement = await RentalAgreementFactory.deploy(
    tenant.address,
    arbiter.address,
    rentAmount,
    depositAmount,
    contractIPFSHash,
    isStablecoinPayment,
    stablecoinAddress,
    priceFeedAddress,
    paymentDueDate
  );
  await rentalAgreement.waitForDeployment();

  const rentalAddress = await rentalAgreement.getAddress();
  console.log(`RentalAgreement deployed to: ${rentalAddress}`);

  // === EXPORT PRO FRONTEND ===
  const outDir = path.join(__dirname, "../frontend/abi");
  fs.mkdirSync(outDir, { recursive: true });

  // 1) ABI-only (na attach k už nasazenému kontraktu)
  const artifact = await hre.artifacts.readArtifact("contracts/RentalAgreement.sol:RentalAgreement");
  fs.writeFileSync(path.join(outDir, "RentalAgreement.abi.json"), JSON.stringify(artifact.abi, null, 2));

  // 2) Adresy nasazených kontraktů
  fs.writeFileSync(path.join(outDir, "RentalAgreement.address.json"), JSON.stringify({ address: rentalAddress }, null, 2));
  fs.writeFileSync(path.join(outDir, "MockV3Aggregator.address.json"), JSON.stringify({ address: await mockFeed.getAddress() }, null, 2));

  // 3) ABI + BYTECODE (frontend deploy z prohlížeče tohle potřebuje)
  const full = await hre.artifacts.readArtifact("contracts/RentalAgreement.sol:RentalAgreement");
  const fullPath = path.join(outDir, "RentalAgreement.json"); // <— tohle čte frontend pro deploy
  fs.writeFileSync(fullPath, JSON.stringify({ abi: full.abi, bytecode: full.bytecode }, null, 2));
  console.log(`ABI+bytecode saved to: ${fullPath}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
