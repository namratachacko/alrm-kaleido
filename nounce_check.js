const hre = require("hardhat");

async function main() {
  const [signer] = await hre.ethers.getSigners();
  const p = hre.ethers.provider;
  const latest = await p.getTransactionCount(signer.address, "latest");
  const pending = await p.getTransactionCount(signer.address, "pending");
  console.log("latest nonce :", latest);
  console.log("pending nonce:", pending);
  console.log("pending gap  :", pending - latest);
}
main().catch(console.error);