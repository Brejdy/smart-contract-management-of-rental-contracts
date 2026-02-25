// Ethers v5 is loaded from index.html as global `ethers`.

document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("deployForm");
  const contractAddressDisplay = document.getElementById("contractAddress");

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
      return;
    }

    try {
      await window.ethereum.request({ method: "eth_requestAccounts" });
      const provider = new ethers.providers.Web3Provider(window.ethereum, "any");
      const signer = provider.getSigner();

      const rentalArtifact = await fetch("abi/RentalAgreement.json").then((r) => r.json());
      const abi = rentalArtifact.abi;
      const bytecode = rentalArtifact.bytecode;

      const priceFeedAddress = (await fetch("abi/MockV3Aggregator.address.json").then((r) => r.json())).address;

      let stablecoinAddress = ethers.constants.AddressZero;
      let rentAmount;
      let depositAmount;

      if (currency === "usdc") {
        const tokenAddressJson = await fetch("abi/MockERC20.address.json").then((r) => r.json());
        stablecoinAddress = tokenAddressJson.address;

        const tokenAbi = await fetch("abi/MockERC20.abi.json").then((r) => r.json());
        const token = new ethers.Contract(stablecoinAddress, tokenAbi, signer);
        const decimals = Number(await token.decimals());

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

      await contract.deployed();
      contractAddressDisplay.textContent = "Deployed to: " + contract.address;
      console.log("Contract deployed at:", contract.address);
    } catch (error) {
      console.error("Error during deployment:", error);
      contractAddressDisplay.textContent = "Deployment failed: " + (error?.message || error);
    }
  });
});
