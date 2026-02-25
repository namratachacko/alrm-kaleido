const hre = require("hardhat");
const { createObjectCsvWriter } = require("csv-writer");

function nowMs() { return Date.now(); }
function b32(s) { return hre.ethers.keccak256(hre.ethers.toUtf8Bytes(s)); }

async function sendAndMeasure(txPromise) {
  const t0 = nowMs();
  const tx = await txPromise;
  const receipt = await tx.wait();
  const t1 = nowMs();
  return { txHash: receipt.hash, gasUsed: receipt.gasUsed.toString(), latencyMs: t1 - t0 };
}

async function main() {
  const CONTRACT = process.env.CONTRACT;
  const N = Number(process.env.N || 50);
  if (!CONTRACT) throw new Error("Set CONTRACT=<deployed_address> in env");

  const [signer] = await hre.ethers.getSigners();
  const ALRM = await hre.ethers.getContractFactory("ALRMRegistry");
  const alrm = ALRM.attach(CONTRACT);

  const csv = createObjectCsvWriter({
    path: "results_kaleido.csv",
    header: [
      { id: "platform", title: "platform" },
      { id: "operation", title: "operation" },
      { id: "i", title: "i" },
      { id: "txHash", title: "tx_hash" },
      { id: "gasUsed", title: "gas_used" },
      { id: "latencyMs", title: "latency_ms" },
      { id: "success", title: "success" },
      { id: "error", title: "error" },
    ],
  });

  const rows = [];
  const platform = "Kaleido-EVM";

  for (let i = 0; i < N; i++) {
    const credId = b32("cred:" + i + ":" + Math.random());
    const holderIdHash = b32("holder:" + i);
    const commitment = b32("commit:" + i);
    const pointer = ""; // later we will test with CID

    try {
      const r1 = await sendAndMeasure(alrm.issueCredentialAnchor(credId, holderIdHash, commitment, pointer));
      rows.push({ platform, operation: "IssueAnchor", i, ...r1, success: true, error: "" });

      if (i % 2 === 0) {
        const r2 = await sendAndMeasure(alrm.attestCredential(credId));
        rows.push({ platform, operation: "Attest", i, ...r2, success: true, error: "" });
      }
      if (i % 10 === 0) {
        const r3 = await sendAndMeasure(alrm.revokeCredential(credId, "test"));
        rows.push({ platform, operation: "Revoke", i, ...r3, success: true, error: "" });
      }
    } catch (e) {
      rows.push({
        platform,
        operation: "Issue/Attest/Revoke",
        i,
        txHash: "",
        gasUsed: "",
        latencyMs: "",
        success: false,
        error: (e.message || "error").slice(0, 180),
      });
    }
  }

  await csv.writeRecords(rows);
  console.log("Wrote results_kaleido.csv with", rows.length, "rows");
  console.log("Signer:", signer.address);
}

main().catch((e) => { console.error(e); process.exit(1); });