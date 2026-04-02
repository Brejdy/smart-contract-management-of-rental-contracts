// Uses Ethers v5 loaded globally from the HTML page.
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
        ? "This interface expects the local Hardhat network (chainId 31337)."
        : "Connected to Hardhat localhost. Role-based actions are ready.";
    return provider.getSigner();
  }

  function short(addr) {
    if (!addr) return "";
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  }

  function humanAmount(bn) {
    try {
      return ethers.utils.formatEther(bn);
    } catch (e) {
      return String(bn);
    }
  }

  function summarizeEvents(receipt, contract) {
    const iface = contract.interface;
    const contractAddress = contract.address.toLowerCase();
    const lines = [];

    for (const log of receipt.logs || []) {
      if ((log.address || "").toLowerCase() !== contractAddress) continue;

      let parsed;
      try {
        parsed = iface.parseLog(log);
      } catch {
        continue;
      }

      const { name, args } = parsed;

      if (name === "RentPaid") {
        const [tenant, amount, stable] = args;
        lines.push(`RentPaid: ${humanAmount(amount)} ${stable ? "stablecoin" : "ETH"} by ${short(tenant)}`);
      } else if (name === "DepositPaid") {
        const [tenant, amount, stable] = args;
        lines.push(`DepositPaid: ${humanAmount(amount)} ${stable ? "stablecoin" : "ETH"} by ${short(tenant)}`);
      } else if (name === "ExcesRentReturned") {
        const [tenant, amount] = args;
        lines.push(`Excess returned to ${short(tenant)}: ${humanAmount(amount)} ETH`);
      } else if (name === "DepositReturned") {
        const [tenant, amount] = args;
        lines.push(`DepositReturned to ${short(tenant)}: ${humanAmount(amount)}`);
      } else if (name === "DepositDeducted") {
        const [, amount, reason] = args;
        lines.push(`DepositDeducted: ${humanAmount(amount)} | reason: ${reason}`);
      } else if (name === "SevereBreachWarningRequested") {
        const [tenant] = args;
        lines.push(`Warning requested for ${short(tenant)}`);
      } else if (name === "SevereBreachWarningIssued") {
        const [tenant, count] = args;
        lines.push(`Warning confirmed for ${short(tenant)} | total warnings: ${count}`);
      } else if (name === "PaymentMissed") {
        const [tenant, missed] = args;
        lines.push(`PaymentMissed by ${short(tenant)}: ${humanAmount(missed)} USD`);
      } else if (name === "PaymentDueDateUpdate") {
        const [ts] = args;
        lines.push(`Next payment date: ${new Date(Number(ts) * 1000).toLocaleString()}`);
      } else if (name === "TerminationScheduled") {
        const [ts] = args;
        lines.push(`Termination scheduled at: ${new Date(Number(ts) * 1000).toLocaleString()}`);
      } else if (name === "ContractTerminated") {
        const [, reason] = args;
        lines.push(`ContractTerminated: ${reason}`);
      } else if (name === "ContractRenewed") {
        const [end] = args;
        lines.push(`Contract renewed. New end: ${new Date(Number(end) * 1000).toLocaleString()}`);
      } else if (name === "ContractRenewalRequested") {
        lines.push("Renewal requested.");
      } else if (name === "AutoPaymentApproved") {
        lines.push("Auto-payment approved.");
      } else if (name === "AutoPaymentRevoked") {
        lines.push("Auto-payment revoked.");
      } else if (name === "AutoPaymentProcessed") {
        const [triggeredBy, tenant, amount, periodKey] = args;
        lines.push(
          `AutoPaymentProcessed: ${humanAmount(amount)} stablecoin | tenant=${short(tenant)} | by=${short(triggeredBy)} | period=${periodKey.toString()}`
        );
      } else {
        const pretty = Object.entries(args)
          .filter(([k]) => !/^\d+$/.test(k))
          .map(([k, v]) => `${k}=${v}`)
          .join(", ");
        lines.push(`${name}${pretty ? `: ${pretty}` : ""}`);
      }
    }

    return lines;
  }

  async function sendTxAndAlert(actionPromise, description, postReadFn) {
    try {
      const tx = await actionPromise;
      const receipt = await tx.wait();
      const extraEvents = (await (typeof postReadFn === "function" ? postReadFn() : null)) || "";
      const fallbackEvents =
        receipt && receipt.logs
          ? summarizeEvents(
              receipt,
              tx.to ? { address: tx.to, interface: tx.interface || null } : actionPromise.contract
            )
          : [];

      let eventSummary = "";
      if (actionPromise.contract) {
        eventSummary = summarizeEvents(receipt, actionPromise.contract).join("\n");
      } else if (tx && tx.to && window.__lastLoadedContract) {
        eventSummary = summarizeEvents(receipt, window.__lastLoadedContract).join("\n");
      } else {
        eventSummary = fallbackEvents.join("\n");
      }

      const msg =
        `${description}\nTx hash: ${receipt.transactionHash}` +
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
      loadBtn.disabled = true;
      loadBtn.textContent = "Loading...";

      const signer = await getSignerOnHardhat();
      const userAddress = (await signer.getAddress()).toLowerCase();
      const artifact = await fetch("abi/RentalAgreement.json").then((r) => r.json());
      const abi = artifact.abi;
      const contract = new ethers.Contract(contractAddress, abi, signer);
      window.__lastLoadedContract = contract;

      const hasMethod = (name) => typeof contract[name] === "function";
      const supportsCurrentPrice = hasMethod("currentEthUsdPrice");

      const [landlord, tenant, arbiter] = await Promise.all([
        contract.landlord(),
        contract.tenant(),
        contract.arbiter(),
      ]);

      let role = "Viewer";
      if (userAddress === landlord.toLowerCase()) role = "Landlord";
      if (userAddress === tenant.toLowerCase()) role = "Tenant";
      if (userAddress === arbiter.toLowerCase()) role = "Arbiter";

      if (role === "Viewer") {
        infoDiv.innerHTML = `
          <h3>Contract loaded</h3>
          <p><strong>Your role:</strong> Viewer</p>
          <p>You are not one of the participants recorded in this contract, so management actions stay hidden.</p>
        `;
        return;
      }

      const [
        rentAmount,
        depositAmount,
        contractIPFSHash,
        isStablecoinPayment,
        stablecoinAddress,
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
        supportsCurrentPrice ? contract.currentEthUsdPrice() : ethers.constants.Zero,
        contract.renewalRequested(),
      ]);

      const fmtAmount = (amountBN) => {
        if (!amountBN) return "0";
        if (isStablecoinPayment) return ethers.utils.formatUnits(amountBN, 6);
        return ethers.utils.formatEther(amountBN);
      };

      const toDate = (ts) => {
        const n = Number(ts || 0);
        if (!n) return "-";
        return new Date(n * 1000).toLocaleString();
      };

      infoDiv.innerHTML = `
        <h3>Contract overview</h3>
        <p><strong>Your role:</strong> ${role}</p>
        <p><strong>Contract address:</strong> ${contractAddress}</p>
        <p><strong>Landlord:</strong> ${landlord}</p>
        <p><strong>Tenant:</strong> ${tenant}</p>
        <p><strong>Arbiter:</strong> ${arbiter}</p>
        <hr/>
        <p><strong>Rent amount:</strong> ${fmtAmount(rentAmount)} ${isStablecoinPayment ? "USDC" : "ETH-equivalent value"}</p>
        <p><strong>Deposit amount:</strong> ${fmtAmount(depositAmount)} ${isStablecoinPayment ? "USDC" : "ETH-equivalent value"}</p>
        <p><strong>Payment mode:</strong> ${isStablecoinPayment ? "Stablecoin (USDC)" : "ETH"}</p>
        ${isStablecoinPayment ? `<p><strong>Stablecoin address:</strong> ${stablecoinAddress}</p>` : ""}
        <p><strong>Current ETH/USD oracle value:</strong> ${supportsCurrentPrice ? currentPrice.toString() : "N/A in this deployment"}</p>
        <p><strong>Rent due day:</strong> ${paymentDueDate}</p>
        <p><strong>Status:</strong> ${rentalStatusText(rentalStatus)}</p>
        <p><strong>Renewal requested:</strong> ${renewalRequested ? "Yes" : "No"}</p>
        <p><strong>Lease start:</strong> ${toDate(leaseStartTimestamp)}</p>
        <p><strong>Contract end:</strong> ${toDate(contractEndDate)}</p>
        <p><strong>Warning count:</strong> ${warningCount}</p>
        <p><strong>Amount owed (raw):</strong> ${amountOwed.toString()}</p>
        <p><strong>Deposit balance (raw):</strong> ${depositBalance.toString()}</p>
        <p><strong>IPFS hash:</strong> ${contractIPFSHash}</p>
      `;

      function input(id, placeholder = "", type = "text") {
        return `<input id="${id}" type="${type}" placeholder="${placeholder}" />`;
      }

      function btn(label, id, tone = "") {
        const className = tone ? `actionBtn ${tone}` : "actionBtn";
        return `<button class="${className}" id="${id}">${label}</button>`;
      }

      function actionCard({ title, description, controls }) {
        return `
          <div class="action-card">
            <h4>${title}</h4>
            <p>${description}</p>
            <div class="action-card-controls">${controls}</div>
          </div>
        `;
      }

      let landlordUI = `
        <div class="role-header">
          <h3>Landlord actions</h3>
          <p>These actions let the landlord enforce obligations, react to renewal flow, and manage the security deposit.</p>
        </div>
        ${renewalRequested ? actionCard({
          title: "Approve contract renewal",
          description: "Use this when the tenant has requested a renewal and you agree to extend the lease period.",
          controls: btn("Approve renewal", "act_approveRenewal")
        }) : ""}
        ${actionCard({
          title: "Issue breach warning",
          description: "Request and then confirm a warning to formally record serious tenant misconduct in the contract lifecycle.",
          controls: `${btn("Request warning", "act_reqWarn")}${btn("Confirm warning", "act_confirmWarn")}`
        })}
        ${actionCard({
          title: "Evaluate or execute termination",
          description: "Check whether termination conditions are satisfied and then finalize termination when appropriate.",
          controls: `${btn("Check eligibility", "act_checkTerm")}${btn("Execute termination", "act_execTerm", "danger")}${btn("Terminate if not renewed", "act_termIfNotRenewed", "danger")}`
        })}
        ${isStablecoinPayment ? actionCard({
          title: "Process automatic payment",
          description: "Runs the stablecoin auto-payment flow when the tenant has previously approved it.",
          controls: btn("Process auto payment", "act_processAuto")
        }) : ""}
        ${actionCard({
          title: "Request early termination",
          description: "Starts early termination from the landlord side before the normal contract end date.",
          controls: btn("Request early termination", "act_reqEarly", "danger")
        })}
        ${actionCard({
          title: "Request deposit deduction",
          description: "Specify how much should be deducted from the deposit and explain the reason for arbiter review.",
          controls: `${input("deductUsd", "USD amount", "number")}${input("deductReason", "Deduction reason")}${btn("Request deduction", "act_deduct")}`
        })}
        ${actionCard({
          title: "Return remaining deposit",
          description: "Sends the remaining security deposit back to the tenant when the lease is settled.",
          controls: btn("Return deposit", "act_returnDeposit")
        })}
      `;

      let tenantUI = `
        <div class="role-header">
          <h3>Tenant actions</h3>
          <p>These controls cover payments, lease renewal, and early termination requests from the tenant perspective.</p>
        </div>
        ${actionCard({
          title: "Request contract renewal",
          description: "Notifies the landlord that you want to continue the lease after the current term ends.",
          controls: btn("Request renewal", "act_reqRenewal")
        })}
        ${actionCard({
          title: "Early termination flow",
          description: "Confirm a landlord request or initiate a tenant-side early termination if the lease should end sooner.",
          controls: `${btn("Confirm landlord request", "act_confirmEarly")}${btn("Execute tenant termination", "act_execTenantTerm", "danger")}${btn("Request early termination", "act_earlyTermination", "danger")}`
        })}
        ${isStablecoinPayment ? actionCard({
          title: "Stablecoin allowance",
          description: "Approve how much USDC the contract may transfer from the tenant wallet before calling payment functions.",
          controls: `${input("stableApproveAmount", "Allowance amount", "number")}${btn("Set allowance", "act_stableApprove")}`
        }) : ""}
        ${actionCard({
          title: `Pay monthly rent ${isStablecoinPayment ? "in USDC" : "in ETH"}`,
          description: "Sends the current rent payment and records it into the contract payment history.",
          controls: btn("Pay rent", "act_payRent")
        })}
        ${actionCard({
          title: `Pay security deposit ${isStablecoinPayment ? "in USDC" : "in ETH"}`,
          description: "Transfers the required security deposit so it can remain locked until contract completion or deduction.",
          controls: btn("Pay deposit", "act_payDeposit")
        })}
        ${isStablecoinPayment ? actionCard({
          title: "Automatic payment permission",
          description: "Allow or revoke recurring stablecoin auto-payment for future rent due dates.",
          controls: `${btn("Authorize auto-payment", "act_autoOn")}${btn("Revoke auto-payment", "act_autoOff", "ghost")}`
        }) : ""}
      `;

      let arbiterUI = `
        <div class="role-header">
          <h3>Arbiter actions</h3>
          <p>The arbiter evaluates landlord deduction requests and decides whether the deposit should actually be reduced.</p>
        </div>
        ${actionCard({
          title: "Review deduction requests",
          description: "Inspect one request by ID or list all submitted requests, then approve or reject them with justification.",
          controls: `${input("arbReqId", "Deduction request ID", "number")}${input("arbRejectionReason", "Reason for rejection")}${btn("Show all requests", "act_showAllDeductions", "ghost")}${btn("Show request", "act_showDeduction")}${btn("Approve request", "act_approveDeduction")}${btn("Reject request", "act_rejectDeduction", "danger")}`
        })}
      `;

      let roleUI = "";
      if (role === "Landlord") roleUI = landlordUI;
      else if (role === "Tenant") roleUI = tenantUI;
      else if (role === "Arbiter") roleUI = arbiterUI;

      actionsDiv.innerHTML =
        roleUI +
        `
          <div class="role-header">
            <h3>General contract tools</h3>
            <p>These tools help inspect historical activity that has already been recorded on-chain.</p>
          </div>
          ${actionCard({
            title: "View payment history",
            description: "Shows all recorded rent and deposit transfers registered by this contract.",
            controls: btn("Show payment history", "act_history", "ghost")
          })}
        `;

      document.getElementById("act_history")?.addEventListener("click", async () => {
        const recs = await contract.getPaymentHistory();
        const list = recs
          .map(
            (r) =>
              `- ${new Date(Number(r.timestamp) * 1000).toLocaleString()} | ${r.amount.toString()} wei | ${r.stablecoin ? "stablecoin" : "ETH"}`
          )
          .join("\n");
        alert(list || "No records yet.");
      });

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
        await sendTxAndAlert(contract.checkTermination(), "Termination evaluated", async () => {
          const status = await contract.rentalStatus();
          const ts = await contract.terminationTimeStamp();
          return `rentalStatus=${rentalStatusText(status)}\nterminationTimeStamp=${Number(ts) ? new Date(Number(ts) * 1000).toLocaleString() : "-"}`;
        });
      });

      document.getElementById("act_processAuto")?.addEventListener("click", async () => {
        if (!isStablecoinPayment) {
          alert("ETH auto-payment is not part of this project version.");
          return;
        }

        await sendTxAndAlert(contract.processAutoPayment(), "Auto payment processed", async () => {
          const owed = await contract.amountOwed();
          return `amountOwed=${owed.toString()}`;
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
        const usd = (document.getElementById("deductUsd").value || "").trim();
        const reason = (document.getElementById("deductReason").value || "").trim();

        if (!usd || Number(usd) <= 0) {
          alert("Enter USD amount.");
          return;
        }

        const usdAmount = isStablecoinPayment
          ? ethers.utils.parseUnits(usd, 6)
          : ethers.utils.parseEther(usd);

        await sendTxAndAlert(
          contract.requestDeduction(usdAmount, reason, ""),
          "Deposit deduction requested for arbiter review",
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

      document.getElementById("act_stableApprove")?.addEventListener("click", async () => {
        try {
          if (!isStablecoinPayment) {
            alert("This contract is not in stablecoin mode.");
            return;
          }

          const rawAmount = (document.getElementById("stableApproveAmount")?.value || "").trim();
          if (!rawAmount || Number(rawAmount) <= 0) {
            alert("Enter amount to approve.");
            return;
          }

          const tokenAbi = await fetch("abi/MockERC20.abi.json").then((r) => r.json());
          const token = new ethers.Contract(stablecoinAddress, tokenAbi, signer);
          const decimals = Number(await token.decimals());
          const approveAmount = ethers.utils.parseUnits(rawAmount, decimals);

          await sendTxAndAlert(
            token.approve(contract.address, approveAmount),
            "Stablecoin allowance updated",
            async () => {
              const allowance = await token.allowance(await signer.getAddress(), contract.address);
              return `allowance=${allowance.toString()}`;
            }
          );
        } catch (err) {
          console.error(err);
          alert(`Error: ${err?.data?.message ?? err.message ?? err}`);
        }
      });

      document.getElementById("act_payRent")?.addEventListener("click", async () => {
        try {
          if (isStablecoinPayment) {
            await sendTxAndAlert(contract.payRent(), "Rent paid (stablecoin)", async () => {
              const owed = await contract.amountOwed();
              const len = (await contract.getPaymentHistory()).length;
              return `amountOwed=${owed.toString()}\npaymentHistoryCount=${len}`;
            });
            return;
          }

          const provider = new ethers.providers.Web3Provider(window.ethereum);
          const required = await contract.quoteRentInWei();
          const beforeL = await provider.getBalance(landlord);

          await sendTxAndAlert(contract.payRent({ value: required }), "Rent paid (ETH)", async () => {
            const afterL = await provider.getBalance(landlord);
            const owed = await contract.amountOwed();
            const len = (await contract.getPaymentHistory()).length;
            return `amountOwed=${owed.toString()}\npaymentHistoryCount=${len}\nlandlordDelta=${ethers.utils.formatEther(afterL.sub(beforeL))} ETH`;
          });
        } catch (err) {
          console.error("[RENT ETH] error:", err);
          alert(`Error: ${err?.data?.message ?? err.message ?? err}`);
        }
      });

      document.getElementById("act_payDeposit")?.addEventListener("click", async () => {
        try {
          if (isStablecoinPayment) {
            await sendTxAndAlert(contract.payDeposit(), "Deposit paid (stablecoin)", async () => {
              const bal = await contract.depositBalance();
              return `depositBalance=${bal.toString()}`;
            });
            return;
          }

          const provider = new ethers.providers.Web3Provider(window.ethereum);
          const required = await contract.quoteDepositInWei();
          const beforeC = await provider.getBalance(contract.address);

          await sendTxAndAlert(contract.payDeposit({ value: required }), "Deposit paid (ETH)", async () => {
            const afterC = await provider.getBalance(contract.address);
            const bal = await contract.depositBalance();
            return `depositBalance=${bal.toString()}\ncontractDelta=${ethers.utils.formatEther(afterC.sub(beforeC))} ETH`;
          });
        } catch (err) {
          console.error("[DEPOSIT ETH] error:", err);
          alert(`Error: ${err?.data?.message ?? err.message ?? err}`);
        }
      });

      document.getElementById("act_approveRenewal")?.addEventListener("click", async () => {
        await sendTxAndAlert(contract.approveContractRenewal(), "Renewal approved", async () => {
          const end = await contract.contractEndDate();
          return `contractEndDate=${new Date(Number(end) * 1000).toLocaleString()}`;
        });
      });

      document.getElementById("act_showAllDeductions")?.addEventListener("click", async () => {
        try {
          let reqs = [];

          if (typeof contract.getAllDeductionRequests === "function") {
            reqs = await contract.getAllDeductionRequests();
          } else {
            for (let i = 0; i < 1000; i++) {
              try {
                const req = await contract.deductionRequests(i);
                reqs.push(req);
              } catch {
                break;
              }
            }
          }

          if (!reqs.length) {
            alert("No deduction requests yet.");
            return;
          }

          const lines = reqs.map(
            (req, id) =>
              `#${id} | amount=${req.amount.toString()} USD | approved=${req.approval} | rejected=${req.rejected} | reason="${req.reason}" | rejectionReason="${req.rejectionReason}"`
          );
          alert(lines.join("\n"));
        } catch (e) {
          console.error(e);
          alert(`Cannot read deduction requests: ${e?.data?.message ?? e.message ?? e}`);
        }
      });

      document.getElementById("act_showDeduction")?.addEventListener("click", async () => {
        const idRaw = document.getElementById("arbReqId").value;
        const id = Number(idRaw);
        if (!Number.isInteger(id) || id < 0) {
          alert("Enter valid request ID (0 = first request).");
          return;
        }

        try {
          const req = await contract.deductionRequests(id);
          alert(
            `Request #${id}\n` +
            `amount (USD): ${req.amount.toString()}\n` +
            `reason: ${req.reason}\n` +
            `approved: ${req.approval}\n` +
            `rejected: ${req.rejected}\n` +
            `reason for rejection: ${req.rejectionReason}`
          );
        } catch (e) {
          console.error(e);
          alert("Cannot read request. The ID may be invalid.");
        }
      });

      document.getElementById("act_approveDeduction")?.addEventListener("click", async () => {
        const idRaw = document.getElementById("arbReqId").value;
        const id = Number(idRaw);
        if (!Number.isInteger(id) || id < 0) {
          alert("Enter valid request ID.");
          return;
        }

        await sendTxAndAlert(
          contract.approveDeduction(id),
          "Deduction approved by arbiter",
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
        if (!Number.isInteger(id) || id < 0) {
          alert("Enter valid request ID.");
          return;
        }

        const reason = (document.getElementById("arbRejectionReason").value || "").trim();
        if (!reason && !confirm("No rejection reason entered. Reject anyway?")) {
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
      infoDiv.innerHTML = `<p class="status-text error">Error: ${err.message || err}</p>`;
    } finally {
      loadBtn.disabled = false;
      loadBtn.textContent = "Load contract";
    }
  });
});
