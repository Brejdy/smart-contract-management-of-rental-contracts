// POZOR: nepoužívej už import z v6.
// Ethers v5 je načtený v index.html jako UMD a je k dispozici přes globální `ethers`.

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

    console.log("Deploying with values:", {
      tenantAddress, rent, deposit, contractHash, currency, paymentDay
    });

    try {
      // MetaMask připojení
      await window.ethereum.request({ method: "eth_requestAccounts" });
      const provider = new ethers.providers.Web3Provider(window.ethereum, "any");
      await provider.send("eth_requestAccounts", []);
      const signer = provider.getSigner();

      // Artefakt z Hardhatu
      const artifact = await fetch("abi/RentalAgreement.json").then((r) => r.json());
      const abi = artifact.abi;
      const bytecode = artifact.bytecode;

      console.log("ABI len:", abi?.length);
      console.log("Bytecode head:", typeof bytecode === "string" ? bytecode.slice(0, 10) : bytecode);

      // převody na wei (v5)
      const rentAmount = ethers.utils.parseEther(rent || "0");
      const depositAmount = ethers.utils.parseEther(deposit || "0");

      // mock adresy – nahraď, pokud máš lokální USDC a price feed
      const priceFeedAddress = (await fetch("abi/MockV3Aggregator.address.json").then(r=>r.json())).address;
      const stablecoinAddress = "0x0000000000000000000000000000000000000000"; // když je currency === "ETH"

      // ContractFactory (v5)
      const factory = new ethers.ContractFactory(abi, bytecode, signer);

      const contract = await factory.deploy(
        tenantAddress,
        arbiterAddress,
        rentAmount,
        depositAmount,
        contractHash,
        (currency === "usdc"),   // isStablecoinPayment
        stablecoinAddress,       // _stablecoinAddress
        priceFeedAddress,        // _priceFeed
        paymentDay               // _paymentDueDate (u tebe "den v měsíci")
      );

      console.log("Deployment tx hash:", contract.deployTransaction?.hash);
      await contract.deployed(); // v5 čekání na deploy

      contractAddressDisplay.textContent = "Deployed to: " + contract.address;
      console.log("Contract deployed at:", contract.address);
    } catch (error) {
      console.error("Error during deployment:", error);
      contractAddressDisplay.textContent = "Deployment failed: " + (error?.message || error);
    }
  });
});