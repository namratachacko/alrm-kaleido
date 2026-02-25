const hre = require("hardhat");

async function main() {
  const CONTRACT = process.env.CONTRACT;
  if (!CONTRACT) throw new Error("Set CONTRACT=<deployed_address> in env");

  const [deployer] = await hre.ethers.getSigners();
  console.log("Using deployer:", deployer.address);

  const ALRM = await hre.ethers.getContractFactory("ALRMRegistry");
  const alrm = ALRM.attach(CONTRACT);

  // 1) Grant deployer as Attester (MoE/ABC) for testing
  let tx = await alrm.grantAttester(deployer.address);
  console.log("grantAttester tx:", tx.hash);
  await tx.wait();

  // 2) Register deployer as an accredited Issuer (HEI) for testing
  tx = await alrm.registerIssuer(deployer.address, "TEST-HEI", 0, 0, true);
  console.log("registerIssuer tx:", tx.hash);
  await tx.wait();

  console.log("Setup complete.");
}

main().catch((e) => { console.error(e); process.exit(1); });