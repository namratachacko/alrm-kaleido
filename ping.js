const hre = require("hardhat");

async function main() {
  const net = await hre.ethers.provider.getNetwork();
  const bn = await hre.ethers.provider.getBlockNumber();
  console.log("chainId =", net.chainId.toString());
  console.log("blockNumber =", bn);
}

main().catch((e) => { console.error(e); process.exit(1); });