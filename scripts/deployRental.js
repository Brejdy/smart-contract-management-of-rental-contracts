const fs = require("fs");
const path = require("path");
const hre = require("hardhat");

async function main() {
  const [, tenant, arbiter] = await hre.ethers.getSigners();

  const networkName = hre.network.name;
  const knownEthUsdFeeds = {
    sepolia: "0x694AA1769357215DE4FAC081bf1f309aDC325306",
    mainnet: "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
  };

  let priceFeedAddress = process.env.ETH_USD_FEED_ADDRESS || knownEthUsdFeeds[networkName];
  let mockFeedAddress = null;

  if (!priceFeedAddress) {
    const MockV3Aggregator = await hre.ethers.getContractFactory("MockV3Aggregator");
    const FEED_DECIMALS = 8;
    const INITIAL_ANSWER = hre.ethers.parseUnits("2000", FEED_DECIMALS);
    const mockFeed = await MockV3Aggregator.deploy(FEED_DECIMALS, INITIAL_ANSWER);
    await mockFeed.waitForDeployment();
    priceFeedAddress = await mockFeed.getAddress();
    mockFeedAddress = priceFeedAddress;
    console.log(`MockV3Aggregator deployed to: ${priceFeedAddress}`);
  } else {
    console.log(`Using Chainlink ETH/USD feed on ${networkName}: ${priceFeedAddress}`);
  }

  const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
  const USDC_DECIMALS = 6;
  const mockUSDC = await MockERC20.deploy(
    "Mock USDC",
    "mUSDC",
    USDC_DECIMALS,
    tenant.address,
    hre.ethers.parseUnits("100000", USDC_DECIMALS)
  );
  await mockUSDC.waitForDeployment();
  const stablecoinAddress = await mockUSDC.getAddress();
  console.log(`MockERC20 (mUSDC) deployed to: ${stablecoinAddress}`);

  const RentalAgreement = await hre.ethers.getContractFactory("RentalAgreement");
  const common = {
    tenant: tenant.address,
    arbiter: arbiter.address,
    contractIPFSHash: "QmSomeIPFSHash",
    paymentDueDate: 5,
  };

  const ethRental = await RentalAgreement.deploy(
    common.tenant,
    common.arbiter,
    hre.ethers.parseEther("1000"),
    hre.ethers.parseEther("2000"),
    common.contractIPFSHash,
    false,
    hre.ethers.ZeroAddress,
    priceFeedAddress,
    common.paymentDueDate
  );
  await ethRental.waitForDeployment();
  const ethRentalAddress = await ethRental.getAddress();
  console.log(`ETH RentalAgreement deployed to: ${ethRentalAddress}`);

  const stableRental = await RentalAgreement.deploy(
    common.tenant,
    common.arbiter,
    hre.ethers.parseUnits("1000", USDC_DECIMALS),
    hre.ethers.parseUnits("2000", USDC_DECIMALS),
    common.contractIPFSHash,
    true,
    stablecoinAddress,
    priceFeedAddress,
    common.paymentDueDate
  );
  await stableRental.waitForDeployment();
  const stableRentalAddress = await stableRental.getAddress();
  console.log(`Stablecoin RentalAgreement deployed to: ${stableRentalAddress}`);

  const outDir = path.join(__dirname, "../frontend/abi");
  fs.mkdirSync(outDir, { recursive: true });

  const rentalArtifact = await hre.artifacts.readArtifact("contracts/RentalAgreement.sol:RentalAgreement");
  fs.writeFileSync(path.join(outDir, "RentalAgreement.abi.json"), JSON.stringify(rentalArtifact.abi, null, 2));
  fs.writeFileSync(path.join(outDir, "RentalAgreement.json"), JSON.stringify({ abi: rentalArtifact.abi, bytecode: rentalArtifact.bytecode }, null, 2));

  const mockErc20Artifact = await hre.artifacts.readArtifact("contracts/MockERC20.sol:MockERC20");
  fs.writeFileSync(path.join(outDir, "MockERC20.abi.json"), JSON.stringify(mockErc20Artifact.abi, null, 2));
  fs.writeFileSync(path.join(outDir, "MockERC20.json"), JSON.stringify({ abi: mockErc20Artifact.abi, bytecode: mockErc20Artifact.bytecode }, null, 2));

  const mockFeedArtifact = await hre.artifacts.readArtifact("contracts/MockV3Aggregator.sol:MockV3Aggregator");
  fs.writeFileSync(path.join(outDir, "MockV3Aggregator.abi.json"), JSON.stringify(mockFeedArtifact.abi, null, 2));
  fs.writeFileSync(path.join(outDir, "MockV3Aggregator.json"), JSON.stringify({ abi: mockFeedArtifact.abi, bytecode: mockFeedArtifact.bytecode }, null, 2));

  if (mockFeedAddress) {
    fs.writeFileSync(path.join(outDir, "MockV3Aggregator.address.json"), JSON.stringify({ address: mockFeedAddress }, null, 2));
  }
  fs.writeFileSync(path.join(outDir, "MockERC20.address.json"), JSON.stringify({ address: stablecoinAddress }, null, 2));
  fs.writeFileSync(path.join(outDir, "RentalAgreement.address.json"), JSON.stringify({ address: ethRentalAddress }, null, 2));
  fs.writeFileSync(
    path.join(outDir, "RentalAgreement.addresses.json"),
    JSON.stringify(
      {
        eth: ethRentalAddress,
        stable: stableRentalAddress,
      },
      null,
      2
    )
  );

  console.log("Frontend ABI/address files were updated in frontend/abi");
  console.log("Use RentalAgreement.addresses.json to test both modes quickly.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
