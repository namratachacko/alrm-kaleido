const hre = require("hardhat");
const fs = require("fs");

function nowMs() { return Date.now(); }
function b32(s) { return hre.ethers.keccak256(hre.ethers.toUtf8Bytes(s)); }

async function issueOne(alrm, i, nonce, feeOverrides) {
  const credId = b32("cred:" + i + ":" + Math.random());
  const holderIdHash = b32("holder:" + i);
  const commitment = b32("commit:" + i);
  const pointer = "";

  const tx = await alrm.issueCredentialAnchor(
    credId,
    holderIdHash,
    commitment,
    pointer,
    {
      nonce,
      gasLimit: 300000,
      ...feeOverrides,
    }
  );
  return tx.wait();
}

async function getFeeOverrides(provider) {
  // Works for both EIP-1559 and legacy networks
  const feeData = await provider.getFeeData();

  // If EIP-1559 fields exist, use them
  if (feeData.maxFeePerGas && feeData.maxPriorityFeePerGas) {
    // small bump for safety
    return {
      maxFeePerGas: feeData.maxFeePerGas * 2n,
      maxPriorityFeePerGas: feeData.maxPriorityFeePerGas * 2n,
    };
  }

  // Otherwise use legacy gasPrice
  if (feeData.gasPrice) {
    return { gasPrice: feeData.gasPrice * 2n };
  }

  return {};
}

async function runBatch(concurrency, totalTx) {
  const CONTRACT = process.env.CONTRACT;
  if (!CONTRACT) throw new Error("Set CONTRACT=<address>");

  const [signer] = await hre.ethers.getSigners();
  const provider = hre.ethers.provider;

  const ALRM = await hre.ethers.getContractFactory("ALRMRegistry");
  const alrm = ALRM.attach(CONTRACT);

  const feeOverrides = await getFeeOverrides(provider);

  // 👇 critical: start from pending nonce to avoid collisions with any pending tx
  let nextNonce = await provider.getTransactionCount(signer.address, "pending");

  console.log(`\nRunning concurrency = ${concurrency}, totalTx = ${totalTx}`);
  console.log(`Starting nonce (pending) = ${nextNonce}`);

  const start = nowMs();
  let sent = 0;

  while (sent < totalTx) {
    const batch = [];
    for (let k = 0; k < concurrency && sent < totalTx; k++) {
      batch.push(issueOne(alrm, sent, nextNonce, feeOverrides));
      nextNonce += 1;
      sent += 1;
    }
    await Promise.all(batch);
  }

  const end = nowMs();
  const durationSec = (end - start) / 1000;
  const tps = totalTx / durationSec;

  return { concurrency, totalTx, durationSec, tps };
}

async function main() {
  const levels = [1, 5, 10, 20];
  const totalTx = Number(process.env.TOTAL_TX || 50);

  const results = [];
  for (const c of levels) {
    const r = await runBatch(c, totalTx);
    results.push(r);
    console.log(`TPS @ ${c} = ${r.tps.toFixed(2)}`);
  }

  fs.writeFileSync("tps_kaleido.json", JSON.stringify(results, null, 2));
  console.log("\nSaved results to tps_kaleido.json");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});