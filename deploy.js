const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying from:", deployer.address);

  const ALRM = await hre.ethers.getContractFactory("ALRMRegistry");
  const alrm = await ALRM.deploy(deployer.address);
  await alrm.waitForDeployment();

  console.log("ALRMRegistry deployed to:", await alrm.getAddress());
}

main().catch((e) => { console.error(e); process.exit(1); });