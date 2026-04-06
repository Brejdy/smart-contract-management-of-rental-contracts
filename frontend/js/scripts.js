// Ethers v5 is loaded from index.html as global `ethers`.

document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("deployForm");
  const contractAddressDisplay = document.getElementById("contractAddress");
  const deployButton = document.getElementById("deployButton");

  async function fetchJsonOrNull(path) {
    try {
      const response = await fetch(path);
      if (!response.ok) return null;
      return await response.json();
    } catch {
      return null;
    }
  }

  async function resolveLiveDependency({
    provider,
    signer,
    artifactPath,
    abiPath,
    addressPath,
    deployArgs,
    label,
  }) {
    const knownAddress = (await fetchJsonOrNull(addressPath))?.address;
    if (knownAddress && ethers.utils.isAddress(knownAddress)) {
      const code = await provider.getCode(knownAddress);
      if (code && code !== "0x") {
        return knownAddress;
      }
    }

    const artifact = await fetchJsonOrNull(artifactPath);
    if (!artifact?.abi || !artifact?.bytecode) {
      const abiOnly = await fetchJsonOrNull(abiPath);
      if (abiOnly?.length && knownAddress && ethers.utils.isAddress(knownAddress)) {
        throw new Error(
          `${label} address points to a non-existent contract on the current chain. Re-run the deploy export script or add ${artifactPath}.`
        );
      }
      throw new Error(`${label} artifact is missing. Run the deploy export script once to create ${artifactPath}.`);
    }

    const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, signer);
    const instance = await factory.deploy(...deployArgs);
    await instance.deployed();
    return instance.address;
  }

  form.addEventListener("submit", async (e) => {
    e.preventDefault();

    const tenantAddress = document.getElementById("tenant").value.trim();
    const arbiterAddress = document.getElementById("arbiter").value.trim();
    const rent = document.getElementById("rent").value.trim();
    const deposit = document.getElementById("deposit").value.trim();
    const contractHash = document.getElementById("contractHash").value.trim();
    const currency = document.getElementById("currency").value;
    const paymentDay = parseInt(document.getElementById("paymentDay").value, 10);

    if (!ethers.utils.isAddress(tenantAddress) || !ethers.utils.isAddress(arbiterAddress)) {
      contractAddressDisplay.textContent = "Invalid tenant or arbiter address.";
      contractAddressDisplay.className = "status-text error";
      return;
    }

    try {
      deployButton.disabled = true;
      deployButton.textContent = "Deploying...";
      contractAddressDisplay.textContent = "Preparing deployment. Confirm the transaction in your wallet.";
      contractAddressDisplay.className = "status-text";

      await window.ethereum.request({ method: "eth_requestAccounts" });
      const provider = new ethers.providers.Web3Provider(window.ethereum, "any");
      const signer = provider.getSigner();

      const rentalArtifact = await fetch("abi/RentalAgreement.json").then((r) => r.json());
      const abi = rentalArtifact.abi;
      const bytecode = rentalArtifact.bytecode;

      let stablecoinAddress = ethers.constants.AddressZero;
      let rentAmount;
      let depositAmount;

      const priceFeedAddress = await resolveLiveDependency({
        provider,
        signer,
        artifactPath: "abi/MockV3Aggregator.json",
        abiPath: "abi/MockV3Aggregator.abi.json",
        addressPath: "abi/MockV3Aggregator.address.json",
        deployArgs: [8, ethers.utils.parseUnits("2000", 8)],
        label: "Mock ETH/USD oracle",
      });

      if (currency === "usdc") {
        const tokenArtifact = await fetch("abi/MockERC20.json").then((r) => r.json());
        const tokenAbi = tokenArtifact.abi;
        const tokenFactory = new ethers.ContractFactory(tokenAbi, tokenArtifact.bytecode, signer);
        const deployedToken = await tokenFactory.deploy(
          "Mock USDC",
          "mUSDC",
          6,
          tenantAddress,
          ethers.utils.parseUnits("100000", 6)
        );
        await deployedToken.deployed();
        stablecoinAddress = deployedToken.address;

        const stablecoin = new ethers.Contract(stablecoinAddress, tokenAbi, signer);
        const decimals = Number(await stablecoin.decimals());

        rentAmount = ethers.utils.parseUnits(rent || "0", decimals);
        depositAmount = ethers.utils.parseUnits(deposit || "0", decimals);
      } else {
        rentAmount = ethers.utils.parseEther(rent || "0");
        depositAmount = ethers.utils.parseEther(deposit || "0");
      }

      const factory = new ethers.ContractFactory(abi, bytecode, signer);
      const contract = await factory.deploy(
        tenantAddress,
        arbiterAddress,
        rentAmount,
        depositAmount,
        contractHash,
        currency === "usdc",
        stablecoinAddress,
        priceFeedAddress,
        paymentDay
      );

      contractAddressDisplay.textContent = "Transaction submitted. Waiting for the contract deployment to be mined...";
      await contract.deployed();
      contractAddressDisplay.textContent =
        "Contract deployed successfully. Address: " +
        contract.address +
        ". Open the Existing contracts page to inspect or manage it.";
      contractAddressDisplay.className = "status-text success";
      console.log("Contract deployed at:", contract.address);
    } catch (error) {
      console.error("Error during deployment:", error);
      contractAddressDisplay.textContent = "Deployment failed: " + (error?.message || error);
      contractAddressDisplay.className = "status-text error";
    } finally {
      deployButton.disabled = false;
      deployButton.textContent = "Deploy contract";
    }
  });
});
