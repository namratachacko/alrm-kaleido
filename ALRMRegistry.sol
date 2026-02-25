// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * Academic Learning Record Management (ALRM) - Ethereum Anchor Registry
 *
 * Design goals (aligned with paper):
 * - Store minimal on-chain data: hashes/commitments + pointers (e.g., IPFS CID), no plaintext PII.
 * - Role-based governance: HEIs (issuers) issue anchors, ABC/MoE (attester) attests and can co-revoke.
 * - Verifiers are read-only: they can check anchor existence + attestation + revocation status.
 *
 * NOTE:
 * - This contract anchors verifiable credentials (VCs) or transcript commitments.
 * - Actual credentials should be exchanged off-chain and verified via signatures + on-chain anchor match.
 */

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ALRMRegistry is AccessControl, Ownable {
    // --- Roles ---
    bytes32 public constant ISSUER_ROLE   = keccak256("ISSUER_ROLE");   // HEI / University
    bytes32 public constant ATTESTER_ROLE = keccak256("ATTESTER_ROLE"); // ABC/MoE

    // --- Data structures ---

    // Issuer registry entry (accredited HEIs)
    struct IssuerInfo {
        bool accredited;
        string name;          // optional human-readable label
        uint64 validFrom;     // unix seconds
        uint64 validTo;       // unix seconds (0 => no expiry)
    }

    // Credential anchor record (hash/commitment + metadata pointer)
    struct CredentialAnchor {
        address issuer;        // issuing HEI
        bytes32 holderIdHash;  // hash of learner identifier (e.g., keccak256(ABC_ID or DID))
        bytes32 commitment;    // hash/commitment of credential/VC/transcript root
        string  pointer;       // IPFS CID / secure repo reference (optional)
        uint64  issuedAt;      // unix seconds
        bool    attested;      // set by ABC/MoE (policy-dependent)
        bool    revoked;       // revocation status
        uint64  revokedAt;     // unix seconds
        string  revokeReason;  // short reason code/text (keep minimal)
    }

    // --- Storage ---
    mapping(address => IssuerInfo) public issuers;               // HEI address => info
    mapping(bytes32 => CredentialAnchor) private anchors;        // credId => anchor
    mapping(bytes32 => bool) private anchorExists;               // credId => existence

    // --- Events ---
    event IssuerRegistered(address indexed issuer, string name, uint64 validFrom, uint64 validTo);
    event IssuerAccreditationUpdated(address indexed issuer, bool accredited);

    event CredentialAnchored(
        bytes32 indexed credId,
        address indexed issuer,
        bytes32 indexed holderIdHash,
        bytes32 commitment,
        string pointer,
        uint64 issuedAt
    );

    event CredentialAttested(bytes32 indexed credId, address indexed attester, uint64 attestedAt);

    event CredentialRevoked(
        bytes32 indexed credId,
        address indexed revokedBy,
        uint64 revokedAt,
        string reason
    );

    // --- Constructor ---
    constructor(address initialOwner) Ownable(initialOwner) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
    }

    // ============================================================
    // Admin / Governance: Issuer registry + role assignment
    // ============================================================

    /**
     * @dev Register or update an issuer (HEI). Owner governs the registry (or delegate to ATTESTER_ROLE if desired).
     * After registering, grant ISSUER_ROLE to enable issuance.
     */
    function registerIssuer(
        address issuer,
        string calldata name,
        uint64 validFrom,
        uint64 validTo,
        bool accredited
    ) external onlyOwner {
        require(issuer != address(0), "issuer=0");
        issuers[issuer] = IssuerInfo({
            accredited: accredited,
            name: name,
            validFrom: validFrom,
            validTo: validTo
        });

        // Role management: grant issuer role if accredited
        if (accredited && !hasRole(ISSUER_ROLE, issuer)) {
            _grantRole(ISSUER_ROLE, issuer);
        }
        emit IssuerRegistered(issuer, name, validFrom, validTo);
        emit IssuerAccreditationUpdated(issuer, accredited);
    }

    /**
     * @dev Toggle accreditation without rewriting name/dates.
     */
    function setIssuerAccreditation(address issuer, bool accredited) external onlyOwner {
        require(issuer != address(0), "issuer=0");
        issuers[issuer].accredited = accredited;

        if (accredited) {
            if (!hasRole(ISSUER_ROLE, issuer)) _grantRole(ISSUER_ROLE, issuer);
        } else {
            if (hasRole(ISSUER_ROLE, issuer)) _revokeRole(ISSUER_ROLE, issuer);
        }
        emit IssuerAccreditationUpdated(issuer, accredited);
    }

    /**
     * @dev Set/Grant attester role (ABC/MoE). Owner controls who can attest.
     */
    function grantAttester(address attester) external onlyOwner {
        require(attester != address(0), "attester=0");
        _grantRole(ATTESTER_ROLE, attester);
    }

    function revokeAttester(address attester) external onlyOwner {
        _revokeRole(ATTESTER_ROLE, attester);
    }

    // ============================================================
    // Issuance: Anchor credential commitment + pointer
    // ============================================================

    /**
     * @notice Anchor a credential/transcript commitment.
     * @param credId Unique credential identifier (UUID hashed to bytes32 OR keccak256 of a unique string).
     * @param holderIdHash keccak256 hash of learner's ABC ID/DID (avoid plaintext IDs on-chain).
     * @param commitment keccak256 hash/commitment of the VC / transcript Merkle root / credential payload.
     * @param pointer Optional IPFS CID or secure repo pointer for the artifact (can be empty).
     */
    function issueCredentialAnchor(
        bytes32 credId,
        bytes32 holderIdHash,
        bytes32 commitment,
        string calldata pointer
    ) external onlyRole(ISSUER_ROLE) {
        require(!anchorExists[credId], "credId exists");
        require(commitment != bytes32(0), "commitment=0");

        // Accreditation/time validity check
        IssuerInfo memory info = issuers[msg.sender];
        require(info.accredited, "issuer not accredited");
        if (info.validFrom != 0) require(block.timestamp >= info.validFrom, "issuer not yet valid");
        if (info.validTo != 0) require(block.timestamp <= info.validTo, "issuer expired");

        anchors[credId] = CredentialAnchor({
            issuer: msg.sender,
            holderIdHash: holderIdHash,
            commitment: commitment,
            pointer: pointer,
            issuedAt: uint64(block.timestamp),
            attested: false,
            revoked: false,
            revokedAt: 0,
            revokeReason: ""
        });

        anchorExists[credId] = true;

        emit CredentialAnchored(
            credId,
            msg.sender,
            holderIdHash,
            commitment,
            pointer,
            uint64(block.timestamp)
        );
    }

    // ============================================================
    // Attestation: ABC/MoE marks credits as attested
    // ============================================================

    /**
     * @notice Attest a previously anchored credential (policy-dependent).
     * Typical use: ABC/MoE validates credit legitimacy and marks attested=true.
     */
    function attestCredential(bytes32 credId) external onlyRole(ATTESTER_ROLE) {
        require(anchorExists[credId], "unknown credId");
        CredentialAnchor storage c = anchors[credId];
        require(!c.revoked, "revoked");
        require(!c.attested, "already attested");
        c.attested = true;

        emit CredentialAttested(credId, msg.sender, uint64(block.timestamp));
    }

    // ============================================================
    // Revocation: Issuer (and optionally Attester) can revoke
    // ============================================================

    /**
     * @notice Revoke a credential anchor (correction/misconduct/withdrawn etc.).
     * Access: issuer of that credential OR an attester.
     */
    function revokeCredential(bytes32 credId, string calldata reason) external {
        require(anchorExists[credId], "unknown credId");
        CredentialAnchor storage c = anchors[credId];
        require(!c.revoked, "already revoked");

        bool isIssuer = (msg.sender == c.issuer) && hasRole(ISSUER_ROLE, msg.sender);
        bool isAttester = hasRole(ATTESTER_ROLE, msg.sender);
        require(isIssuer || isAttester, "not authorized");

        c.revoked = true;
        c.revokedAt = uint64(block.timestamp);
        c.revokeReason = reason;

        emit CredentialRevoked(credId, msg.sender, uint64(block.timestamp), reason);
    }

    // ============================================================
    // Read / Verify helpers (for verifiers/portals)
    // ============================================================

    function getCredentialAnchor(bytes32 credId) external view returns (CredentialAnchor memory) {
        require(anchorExists[credId], "unknown credId");
        return anchors[credId];
    }

    /**
     * @notice Lightweight verification check.
     * @dev Verifier should still validate off-chain signature of VC and then compare commitment.
     */
    function verifyAnchor(
        bytes32 credId,
        bytes32 expectedCommitment
    ) external view returns (bool ok, bool attested, bool revoked, address issuer) {
        if (!anchorExists[credId]) return (false, false, false, address(0));
        CredentialAnchor memory c = anchors[credId];
        ok = (c.commitment == expectedCommitment);
        return (ok, c.attested, c.revoked, c.issuer);
    }

    function isRevoked(bytes32 credId) external view returns (bool) {
        if (!anchorExists[credId]) return false;
        return anchors[credId].revoked;
    }

    function issuerStatus(address issuer) external view returns (IssuerInfo memory) {
        return issuers[issuer];
    }
}