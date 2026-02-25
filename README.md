# alrm-kaleido
Blockchain-Assisted ALRM Smart Contract (EVM Prototype)

This repository contains the Ethereum Virtual Machine (EVM) implementation and benchmarking framework for the Blockchain-Assisted Self-Sovereign Identity (Ba-SSI) enabled Academic Learning Record Management (ALRM) system.

The project implements a role-governed anchor registry for secure academic credential lifecycle management, including:

Credential issuance (hash anchoring)

Authority-based attestation

Revocation mechanisms

Lightweight verification

Performance benchmarking (Gas, Latency, TPS)

This prototype was deployed and experimentally evaluated on a Kaleido EVM permissioned network.

Research Objective

Traditional Academic Bank of Credits (ABC) systems are centralized and vulnerable to:

Credential fraud

Limited portability

Revocation inefficiencies

Manual verification processes

This implementation transforms ABC into a:

Decentralized

Cryptographically verifiable

Role-governed

Commitment-based anchor registry

Only credential commitments (hashes) are stored on-chain.
Full academic artifacts are intended for off-chain storage (e.g., IPFS).

🏗 System Architecture
On-chain:

Issuer accreditation registry

Role-based governance (Owner / Issuer / Attester)

Credential anchoring

Attestation status

Revocation flags

Verification helper functions

Off-chain (conceptual layer):

Verifiable Credentials (VCs)

IPFS artifact storage

SSI wallet-based selective disclosure

📂 Repository Structure
contracts/
  ALRMRegistry.sol        # Main smart contract

scripts/
  deploy.js               # Deploy contract
  setup_roles.js          # Register issuer & attester
  bench.js                # Gas & latency benchmarking
  bench_concurrency.js    # TPS vs concurrency testing
  nonce_check.js          # Debugging utility

results/
  *.csv                   # Benchmark outputs

hardhat.config.js         # Network configuration
⚙️ Prerequisites

Node.js (v18+ recommended)

npm

Hardhat

Access to Kaleido (or any EVM-compatible node)

Funded account private key

🚀 Setup & Deployment
1️⃣ Install dependencies
npm install
2️⃣ Create .env file (root directory)
KALEIDO_RPC_URL="https://APP_USER:APP_PASSWORD@your-kaleido-node"
CHAIN_ID="20"
PRIVATE_KEY="0xYOUR_PRIVATE_KEY"

⚠️ Never commit .env or private keys to GitHub.

3️⃣ Deploy Contract
npx hardhat run scripts/deploy.js --network kaleido

You will see:

Deploying from: <deployer_address>
ALRMRegistry deployed to: <contract_address>
4️⃣ Setup Roles
CONTRACT=<contract_address> npx hardhat run scripts/setup_roles.js --network kaleido

This will:

Grant ATTESTER_ROLE

Register and accredit issuer

Enable credential lifecycle testing

📊 Benchmarking
🔹 Gas + Latency Testing
CONTRACT=<contract_address> N=20 npx hardhat run scripts/bench.js --network kaleido

Outputs:

Gas used per operation

Transaction latency

CSV results file

🔹 TPS vs Concurrency Testing
CONTRACT=<contract_address> TOTAL_TX=100 npx hardhat run scripts/bench_concurrency.js --network kaleido

Tests concurrency levels:

1, 5, 10, 20

Example results (100 transactions):

Concurrency	TPS
1	0.20
5	0.90
10	1.51
20	1.50

Throughput increases until network saturation.

🔐 Smart Contract Design Highlights
Role-Based Governance

OWNER – Admin controls

ISSUER_ROLE – HEIs

ATTESTER_ROLE – ABC/MoE authority

Minimal On-Chain Storage

Stores only:

credId

holderIdHash

commitment

Status flags

Timestamps

No plaintext academic data is stored on-chain.

Revocation Without Mutation

Ledger entries remain immutable.
Revocation updates status flags only.

📈 Performance Metrics Evaluated

Gas consumption (per operation)

Transaction latency

Throughput (TPS)

Scalability under concurrency

Deterministic cost behavior

🧪 Experimental Environment

EVM-compatible network (Kaleido)

PoA-style permissioned deployment

Hardhat-based automation

Controlled concurrency loads
