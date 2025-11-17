// POZOR: Ethers v5 (stejně jako index). Žádný BrowserProvider atd.
window.addEventListener("DOMContentLoaded", async () => {
  const addrInput = document.getElementById("contractAddress");
  const loadBtn = document.getElementById("loadContract");
  const infoDiv = document.getElementById("contractInfo");
  const actionsDiv = document.getElementById("actions");
  const networkNote = document.getElementById("networkNote");

  const rentalStatusText = (code) => {
    if (Number(code) === 0) return "Active";
    if (Number(code) === 1) return "Terminated";
    if (Number(code) === 2) return "PendingTermination";
    return `Unknown(${code})`;
  };

  async function getSignerOnHardhat() {
    if (!window.ethereum) throw new Error("No injected wallet (MetaMask).");
    await window.ethereum.request({ method: "eth_requestAccounts" });
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    const net = await provider.getNetwork();
    networkNote.textContent =
      Number(net.chainId) !== 31337
        ? "This contract is only available on Hardhat localhost (chainId = 31337)."
        : "Network OK: Hardhat localhost.";
    return provider.getSigner();
  }

  // ==== helpers =======================================================

  function short(addr) {
    if (!addr) return "";
    return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
  }

  function humanAmount(bn) {
    try { return ethers.utils.formatEther(bn); } catch (e) { return String(bn); }
  }

  // rozparsuje receipt -> eventy tohoto kontraktu
  function summarizeEvents(receipt, contract) {
    const iface = contract.interface;
    const ca = contract.address.toLowerCase();
    const lines = [];

    for (const log of receipt.logs || []) {
      if ((log.address || "").toLowerCase() !== ca) continue;
      let parsed;
      try { parsed = iface.parseLog(log); } catch { continue; }
      const { name, args } = parsed;

      // hezké zprávy pro známé eventy
      if (name === "RentPaid") {
        const [ten, amount, stable] = args;
        lines.push(`RentPaid: ${humanAmount(amount)} ${stable ? "stablecoin" : "ETH"} by ${short(ten)}`);
      } else if (name === "DepositPaid") {
        const [ten, amount, stable] = args;
        lines.push(`DepositPaid: ${humanAmount(amount)} ${stable ? "stablecoin" : "ETH"} by ${short(ten)}`);
      } else if (name === "ExcesRentReturned") {
        const [ten, amount] = args;
        lines.push(`Excess returned to ${short(ten)}: ${humanAmount(amount)} ETH`);
      } else if (name === "DepositReturned") {
        const [ten, amount] = args;
        lines.push(`DepositReturned to ${short(ten)}: ${humanAmount(amount)}`);
      } else if (name === "DepositDeducted") {
        const [, amount, reason] = args;
        lines.push(`DepositDeducted: ${humanAmount(amount)} | reason: ${reason}`);
      } else if (name === "SevereBreachWarningRequested") {
        const [ten] = args;
        lines.push(`Warning requested for ${short(ten)}`);
      } else if (name === "SevereBreachWarningIssued") {
        const [ten, count] = args;
        lines.push(`Warning confirmed for ${short(ten)} | total warnings: ${count}`);
      } else if (name === "PaymentMissed") {
        const [ten, missed] = args;
        lines.push(`PaymentMissed by ${short(ten)}: ${humanAmount(missed)} USD`);
      } else if (name === "PaymentDueDateUpdate") {
        const [ts] = args;
        lines.push(`Next payment date: ${new Date(Number(ts) * 1000).toLocaleString()}`);
      } else if (name === "TerminationScheduled") {
        const [ts] = args;
        lines.push(`Termination scheduled at: ${new Date(Number(ts) * 1000).toLocaleString()}`);
      } else if (name === "ContractTerminated") {
        const [, reason] = args; // landlord, reason
        lines.push(`ContractTerminated: ${reason}`);
      } else if (name === "ContractRenewed") {
        const [end] = args;
        lines.push(`Contract renewed. New end: ${new Date(Number(end) * 1000).toLocaleString()}`);
      } else if (name === "ContractRenewalRequested") {
        lines.push(`Renewal requested.`);
      } else if (name === "AutoPaymentApproved") {
        lines.push(`Auto-payment approved.`);
      } else if (name === "AutoPaymentRevoked") {
        lines.push(`Auto-payment revoked.`);
      } else {
        // fallback – generický výpis argumentů
        const pretty = Object.entries(args)
          .filter(([k]) => !/^\d+$/.test(k))
          .map(([k, v]) => `${k}=${v}`)
          .join(", ");
        lines.push(`${name}${pretty ? `: ${pretty}` : ""}`);
      }
    }

    return lines;
  }

  // provedu tx, rozparsují eventy + volitelně přečtu stav po tx
  async function sendTxAndAlert(actionPromise, description, postReadFn) {
    try {
      const tx = await actionPromise;
      const receipt = await tx.wait();
      const extraEvents = (await (typeof postReadFn === "function" ? postReadFn() : null)) || "";
      const evLines = receipt && receipt.logs ? summarizeEvents(receipt, tx.to ? { address: tx.to, interface: tx.interface || null } : actionPromise.contract) : [];

      // když nemáme interface z promise, zkusíme jej vytáhnout z tx (u v5 nemusí být)
      let eventSummary = "";
      if (actionPromise.contract) {
        eventSummary = summarizeEvents(receipt, actionPromise.contract).join("\n");
      } else if (tx && tx.to && window.__lastLoadedContract) {
        eventSummary = summarizeEvents(receipt, window.__lastLoadedContract).join("\n");
      } else {
        eventSummary = evLines.join("\n");
      }

      const msg =
        `${description} \nTx hash: ${receipt.transactionHash}` +
        (eventSummary ? `\n\nEvents:\n${eventSummary}` : "") +
        (extraEvents ? `\n\nState:\n${extraEvents}` : "");

      alert(msg);
    } catch (err) {
      console.error(err);
      alert(`Error: ${err && err.data && err.data.message ? err.data.message : (err.message || err)}`);
    }
  }

  loadBtn.addEventListener("click", async () => {
    const contractAddress = addrInput.value.trim();
    infoDiv.innerHTML = "";
    actionsDiv.innerHTML = "";

    if (!/^0x[a-fA-F0-9]{40}$/.test(contractAddress)) {
      alert("Insert valid Ethereum contract address.");
      return;
    }

    try {
      const signer = await getSignerOnHardhat();
      const userAddress = (await signer.getAddress()).toLowerCase();
      const artifact = await fetch("abi/RentalAgreement.json").then((r) => r.json());
      const abi = artifact.abi;
      const contract = new ethers.Contract(contractAddress, abi, signer);
      window.__lastLoadedContract = contract; // aby summarizeEvents mělo iface

      const [landlord, tenant, arbiter] = await Promise.all([contract.landlord(), contract.tenant()]);

      let role = "Viewer";
      if (userAddress === landlord.toLowerCase()) role = "Landlord";
      if (userAddress === tenant.toLowerCase()) role = "Tenant";
      if(userAddress === arbiter.toLowerCase()) role = "Arbiter";

      if (role === "Viewer") {
        infoDiv.innerHTML = `
          <h3>Contract loaded:</h3>
          <p><strong>Your role:</strong> Viewer</p>
          <p>You are not a participant of this contract, so details are hidden</p>
        `;
        return;
      }

      const [
        rentAmount,
        depositAmount,
        contractIPFSHash,
        isStabelcoinPayment,
        stabelcoinAddress,
        paymentDueDate,
        rentalStatus,
        contractEndDate,
        leaseStartTimestamp,
        warningCount,
        amountOwed,
        depositBalance,
        currentPrice,
        renewalRequested,
      ] = await Promise.all([
        contract.rentAmount(),
        contract.depositAmount(),
        contract.contractIPFSHash(),
        contract.isStabelcoinPayment(),
        contract.stabelcoinAddress(),
        contract.paymentDueDate(),
        contract.rentalStatus(),
        contract.contractEndDate(),
        contract.leaseStartTimestamp(),
        contract.warningCount(),
        contract.amountOwed(),
        contract.depositBalance(),
        contract.currentEthUsdPrice(),
        contract.renewalRequested(),
      ]);

      const fmtEth = (weiBN) => ethers.utils.formatEther(weiBN || "0");
      const toDate = (ts) => {
        const n = Number(ts || 0);
        if (!n) return "-";
        return new Date(n * 1000).toLocaleString();
      };

      infoDiv.innerHTML = `
        <h3>Contract loaded</h3>
        <p><strong>Your role:</strong> ${role}</p>
        <p><strong>Address:</strong> ${contractAddress}</p>
        <p><strong>Landlord:</strong> ${landlord}</p>
        <p><strong>Tenant:</strong> ${tenant}</p>
        <p><strong>Arbiter:</strong> ${arbiter}</p>
        <hr/>
        <p><strong>Rent amount (USD):</strong> ${fmtEth(rentAmount)}</p>
        <p><strong>Deposit amount (USD):</strong> ${fmtEth(depositAmount)}</p>
        <p><strong>ETH/USD (1e8):</strong> ${currentPrice.toString()}</p>
        <p><strong>Stablecoin payment:</strong> ${isStabelcoinPayment ? "Yes" : "No"}</p>
        ${isStabelcoinPayment ? `<p><strong>Stablecoin address:</strong> ${stabelcoinAddress}</p>` : ""}
        <p><strong>Payment day:</strong> ${paymentDueDate}</p>
        <p><strong>Status:</strong> ${rentalStatusText(rentalStatus)}</p>
        <p><strong>Renewal requested:</strong> ${renewalRequested ? "Yes" : "No"}</p>
        <p><strong>Lease start:</strong> ${toDate(leaseStartTimestamp)}</p>
        <p><strong>Contract end:</strong> ${toDate(contractEndDate)}</p>
        <p><strong>Warnings:</strong> ${warningCount}</p>
        <p><strong>Amount owed (wei):</strong> ${amountOwed.toString()}</p>
        <p><strong>Deposit balance (wei):</strong> ${depositBalance.toString()}</p>
        <p><strong>IPFS:</strong> ${contractIPFSHash}</p>
      `;

      // === UI ==========================================================
      function btn(label, id) {
        return `<button class="actionBtn" id="${id}">${label}</button>`;
      }
      function input(id, ph = "", type = "text") {
        return `<input id="${id}" type="${type}" placeholder="${ph}" />`;
      }

      let landlordUI = `
        <h3>Landlord</h3>
        ${renewalRequested ? btn("Approve renewal", "act_approveRenewal") : ""}
        ${btn("Request warning", "act_reqWarn")}
        ${btn("Confirm warning", "act_confirmWarn")}
        ${btn("Check termination eligibility", "act_checkTerm")}
        ${btn("Execute termination", "act_execTerm")}
        ${btn("Terminate if not renewed", "act_termIfNotRenewed")}
        ${btn("Request early termination", "act_reqEarly")}
        <div class="card">
          <div><strong>Deduct from deposit (request)</strong></div>
          ${input("deductUsd", "USD amount (integer)", "number")}
          ${input("deductReason", "Reason")}
          ${btn("Request deduction", "act_deduct")}
        </div>
        ${btn("Return deposit", "act_returnDeposit")}
      `;

      let tenantUI = `
        <h3>Tenant</h3>
        ${btn("Request renewal", "act_reqRenewal")}
        ${btn("Confirm early termination", "act_confirmEarly")}
        ${btn("Execute tenant termination", "act_execTenantTerm")}
        ${btn("Request early termination", "act_earlyTermination")}
        <div class="card">
          <div><strong>Pay rent ${isStabelcoinPayment ? "(stablecoin)" : "(ETH)"}</strong></div>
          ${btn("Pay rent", "act_payRent")}
        </div>
        <div class="card">
          <div><strong>Pay deposit ${isStabelcoinPayment ? "(stablecoin)" : "(ETH)"}</strong></div>
          ${btn("Pay deposit", "act_payDeposit")}
        </div>
        <div class="card">
          <div><strong>Auto-payment</strong></div>
          ${btn("Authorize", "act_autoOn")}
          ${btn("Revoke", "act_autoOff")}
        </div>
      `;

      let arbiterUI = `
        <h3>Arbiter</h3>
        <div class="card">
          <div><strong>Deposit deduction request</strong></div>
          ${input("arbReqId", "Deduction Request ID", "number")}
          ${input("arbRejectionReason", "Rejection reason")}
          ${btn("Show request", "act_showDeduction")}
          ${btn("Approve", "act_approveDeduction")}
          ${btn("Reject", "act_rejectDeduction")}

        </div>
      `;

      let roleUI = "";
      if(role === "Landlord") roleUI = landlordUI;
      else if(role === "Tenant") roleUI = tenantUI;
      else if(role === "Arbiter") roleUI = arbiterUI;

      actionsDiv.innerHTML =
        roleUI + `<h3>General</h3>${btn("Show payment history", "act_history")}`;

      // === dráty =======================================================

      // General
      document.getElementById("act_history")?.addEventListener("click", async () => {
        const recs = await contract.getPaymentHistory();
        const list = recs
          .map(
            (r) =>
              `• ${new Date(Number(r.timestamp) * 1000).toLocaleString()} — ${r.amount.toString()} wei — ${r.stablecoin ? "stablecoin" : "ETH"}`
          )
          .join("\n");
        alert(list || "No records yet.");
      });

      // Landlord
      document.getElementById("act_reqWarn")?.addEventListener("click", async () => {
        await sendTxAndAlert(contract.requestWarning(), "Warning requested", async () => {
          const pending = await contract.pendingSevereBreachWarning();
          return `pendingSevereBreachWarning=${pending}`;
        });
      });

      document.getElementById("act_confirmWarn")?.addEventListener("click", async () => {
        await sendTxAndAlert(contract.confirmWarning(), "Warning confirmed", async () => {
          const count = await contract.warningCount();
          const pending = await contract.pendingSevereBreachWarning();
          return `warningCount=${count}\npendingSevereBreachWarning=${pending}`;
        });
      });

      document.getElementById("act_checkTerm")?.addEventListener("click", async () => {
        // funkce nic nevrací – eligible poznáme podle eventu a nového stavu
        await sendTxAndAlert(contract.checkTermination(), "Termination evaluated", async () => {
          const status = await contract.rentalStatus();
          const ts = await contract.terminationTimeStamp();
          return `rentalStatus=${rentalStatusText(status)}\nterminationTimeStamp=${Number(ts) ? new Date(Number(ts) * 1000).toLocaleString() : "-"}`;
        });
      });

      document.getElementById("act_execTerm")?.addEventListener("click", async () => {
        await sendTxAndAlert(contract.executeTermination(), "Termination executed", async () => {
          const status = await contract.rentalStatus();
          return `rentalStatus=${rentalStatusText(status)}`;
        });
      });

      document.getElementById("act_termIfNotRenewed")?.addEventListener("click", async () => {
        await sendTxAndAlert(contract.terminateContractIfNotRenewed(), "Terminated due to non-renewal", async () => {
          const status = await contract.rentalStatus();
          return `rentalStatus=${rentalStatusText(status)}`;
        });
      });

      document.getElementById("act_reqEarly")?.addEventListener("click", async () => {
        await sendTxAndAlert(contract.requestEarlyTerminationByLandLord(), "Early termination requested", async () => {
          const flag = await contract.earlyTerminationRequestedByLandlord();
          return `earlyTerminationRequestedByLandlord=${flag}`;
        });
      });

      document.getElementById("act_deduct")?.addEventListener("click", async () => {
        const usd = document.getElementById("deductUsd").value;
        const reason = (document.getElementById("deductReason").value || "").trim();
        if (!usd || Number(usd) <= 0) return alert("Enter USD amount.");

        await sendTxAndAlert(
          contract.requestDeduction(ethers.BigNumber.from(usd), reason), // ← přidán 2. parametr
          "Deposit deduction requested (waiting for approval)",
          async () => {
            const bal = await contract.depositBalance();
            const ded = await contract.deductedAmount();
            return `depositBalance=${bal.toString()}\ndeductedAmount=${ded.toString()}\nreason="${reason}"`;
          }
        );
      });

      document.getElementById("act_returnDeposit")?.addEventListener("click", async () => {
        await sendTxAndAlert(contract.returnDeposit(), "Deposit returned", async () => {
          const bal = await contract.depositBalance();
          return `depositBalance=${bal.toString()}`;
        });
      });

      // Tenant
      document.getElementById("act_reqRenewal")?.addEventListener("click", async () => {
        await sendTxAndAlert(contract.requestContractRenewal(), "Renewal requested", async () => {
          const req = await contract.renewalRequested();
          return `renewalRequested=${req}`;
        });
      });

      document.getElementById("act_confirmEarly")?.addEventListener("click", async () => {
        await sendTxAndAlert(contract.confirmEarlyTermination(), "Early termination confirmed", async () => {
          const status = await contract.rentalStatus();
          return `rentalStatus=${rentalStatusText(status)}`;
        });
      });

      document.getElementById("act_execTenantTerm")?.addEventListener("click", async () => {
        await sendTxAndAlert(contract.executeTenantTermination(), "Tenant termination executed", async () => {
          const status = await contract.rentalStatus();
          return `rentalStatus=${rentalStatusText(status)}`;
        });
      });

      document.getElementById("act_earlyTermination")?.addEventListener("click", async () => {
        await sendTxAndAlert(contract.requestTerminationByTenant(), "Termination by tenant requested", async () => {
          const status = await contract.rentalStatus();
          return `rentalStatus=${rentalStatusText(status)}`;
        });
      });

      document.getElementById("act_autoOn")?.addEventListener("click", async () => {
        await sendTxAndAlert(contract.authorizeAutoPayment(), "Auto-payment authorized", async () => {
          const ok = await contract.autoPaymentApproved(await signer.getAddress());
          return `autoPaymentApproved=${ok}`;
        });
      });

      document.getElementById("act_autoOff")?.addEventListener("click", async () => {
        await sendTxAndAlert(contract.revokeAutoPayment(), "Auto-payment revoked", async () => {
          const ok = await contract.autoPaymentApproved(await signer.getAddress());
          return `autoPaymentApproved=${ok}`;
        });
      });

      // Tenant — payments
      document.getElementById("act_payRent")?.addEventListener("click", async () => {
        try {
          if (isStabelcoinPayment) {
            await sendTxAndAlert(contract.payRent(), "Rent paid (stablecoin)", async () => {
              const owed = await contract.amountOwed();
              const len = (await contract.getPaymentHistory()).length;
              return `amountOwed=${owed.toString()}\npaymentHistoryCount=${len}`;
            });
            return;
          }

          const provider = new ethers.providers.Web3Provider(window.ethereum);
          const landlordAddr = landlord; // z horního scope
          const required = await contract.quoteRentInWei();

          const beforeL = await provider.getBalance(landlordAddr);
          console.log(`[RENT ETH] sending ${ethers.utils.formatEther(required)} ETH to landlord ${landlordAddr}`);
          console.log(`[RENT ETH] landlord BEFORE = ${ethers.utils.formatEther(beforeL)} ETH`);

          await sendTxAndAlert(contract.payRent({ value: required }), "Rent paid (ETH)", async () => {
            const afterL = await provider.getBalance(landlordAddr);
            console.log(`[RENT ETH] landlord AFTER  = ${ethers.utils.formatEther(afterL)} ETH`);
            console.log(`[RENT ETH] Δ landlord     = +${ethers.utils.formatEther(afterL.sub(beforeL))} ETH`);

            const owed = await contract.amountOwed();
            const len = (await contract.getPaymentHistory()).length;
            return `amountOwed=${owed.toString()}\npaymentHistoryCount=${len}\nlandlordΔ=${ethers.utils.formatEther(afterL.sub(beforeL))} ETH`;
          });
        } catch (err) {
          console.error("[RENT ETH] error:", err);
          alert(`Error: ${err?.data?.message ?? err.message ?? err}`);
        }
      });

      document.getElementById("act_payDeposit")?.addEventListener("click", async () => {
        try {
          if (isStabelcoinPayment) {
            await sendTxAndAlert(contract.payDeposit(), "Deposit paid (stablecoin)", async () => {
              const bal = await contract.depositBalance();
              return `depositBalance=${bal.toString()}`;
            });
            return;
          }

          const provider = new ethers.providers.Web3Provider(window.ethereum);
          const contractAddr = contract.address;
          const required = await contract.quoteDepositInWei();

          const beforeC = await provider.getBalance(contractAddr);
          console.log(`[DEPOSIT ETH] sending ${ethers.utils.formatEther(required)} ETH to contract ${contractAddr}`);
          console.log(`[DEPOSIT ETH] contract BEFORE = ${ethers.utils.formatEther(beforeC)} ETH`);

          await sendTxAndAlert(contract.payDeposit({ value: required }), "Deposit paid (ETH)", async () => {
            const afterC = await provider.getBalance(contractAddr);
            console.log(`[DEPOSIT ETH] contract AFTER  = ${ethers.utils.formatEther(afterC)} ETH`);
            console.log(`[DEPOSIT ETH] Δ contract      = +${ethers.utils.formatEther(afterC.sub(beforeC))} ETH`);

            const bal = await contract.depositBalance();
            return `depositBalance=${bal.toString()}\ncontractΔ=${ethers.utils.formatEther(afterC.sub(beforeC))} ETH`;
          });
        } catch (err) {
          console.error("[DEPOSIT ETH] error:", err);
          alert(`Error: ${err?.data?.message ?? err.message ?? err}`);
        }
      });

      //Landlord – approve renewal
      document.getElementById("act_approveRenewal")?.addEventListener("click", async () => {
        await sendTxAndAlert(contract.approveContractRenewal(), "Renewal approved", async () => {
          const end = await contract.contractEndDate();
          return `contractEndDate=${new Date(Number(end) * 1000).toLocaleString()}`;
        });
      });

      //Arbiter
      document.getElementById("act_showDeduction")?.addEventListener("click", async () => {
        const idRaw = document.getElementById("arbReqId").value;
        const id = Number(idRaw);

        try {
          const req = await contract.deductionRequests(id);
          alert(
            `Request #${id}\n` +
            `amount (USD): ${req.amount.toString()}\n` +
            `reason: ${req.reason}\n` +
            `approved: ${req.approval}`/n + 
            `rejected: ${req.rejected}`/n + 
            `Reason for rejection: ${req.rejectionReason}` 
          );
        } catch (e) {
          console.error(e);
          alert("Cannot read request - invalid ID");
        }
      });

      document.getElementById("act_approveDeduction")?.addEventListener("click", async () => {
        const idRaw = document.getElementById("arbReqId").value;
        const id = Number(idRaw);
        if(!NaN(id) || id < 0)
          return alert("Enter valid request ID");

        await sentTxAndAlert(
          contract.approveDeduction(id),
          "Deduction approved by Arbiter",
          async () => {
            const req = await contract.deductionRequests(id);
            const bal = await contract.depositBalance();
            const ded = await contract.deductedAmount();

            return `request.approved=${req.approval}\ndepositBalance=${bal.toString()}\ndeductedAmount=${ded.toString()}`;
          }
        );
      });

      document.getElementById("act_rejectDeduction")?.addEventListener("click", async () => {
        const idRaw = document.getElementById("arbReqId").value;
        const id = Number(idRaw);
        if(!NaN(id) || id < 0) 
          return alert("Enter valid ID");

        const reason = (document.getElementById("arbRejectReason").value || "").trim();
        if(!reason) {
          if(!confirm("No rejection reason entered. Reject anyway?"))
            return;
        }

        await sendTxAndAlert(
          contract.rejectDeduction(id, reason),
          "Deduction request rejected",
          async () => {
            const req = await contract.deductionRequests(id);
            return (
              `approved=${req.approval}\n` +
              `rejected=${req.rejected}\n` +
              `rejectionReason="${req.rejectionReason}"`
            );
          }
        );
      });
    } catch (err) {
      console.error(err);
      infoDiv.innerHTML = `<p style="color:red;">Error: ${err.message || err}</p>`;
    }
  });
});
