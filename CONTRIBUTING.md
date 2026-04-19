# CONTRIBUTING

This repository is a **read-only architectural standard**. The 29th Regime policies are non-negotiable guardrails, not malleable recommendations.

## Philosophy

Contribution model: **Issue-driven validation, not code-driven development.**

- **No code pull requests.** Infrastructure architecture is a specification, not a product roadmap.
- **No policy overrides.** GDPR, NIS2, FADP requirements cannot be negotiated or exempted.
- **No feature requests.** This repository delivers deterministic enforcement, not feature parity.

## Process: Technical Validation via GitHub Issues

### 1. **Identify a Friction Coefficient**

If you discover a **legitimate technical debt** in the compliance guardrails, file a GitHub Issue with:

- **Title:** `[FRICTION]` prefix followed by technical finding
- **Description:**
  - Specific policy or module affected
  - Evidence (code snippet, configuration file, line number)
  - Impact (operational, compliance, cost)
  - Root cause analysis
  - Severity: CRITICAL, HIGH, MEDIUM, LOW

### Example Issue

```markdown
Title: [FRICTION] data_residency.rego allows non-EU region inadvertently

Description:
- **Affected Policy:** policies/sovereignty/data_residency.rego
- **Line:** 15-20
- **Issue:** The `allowed_eu_regions` list includes "switzerlandnorth", which is non-EU 
  per GDPR Article 32. Switzerland is not an EU member state.
- **Impact:** CRITICAL — Deployments to non-EU regions pass policy enforcement.
- **Root Cause:** Conflation of GDPR-compliant regions with geopolitical EU membership.
```

### 2. **Technical Peer Review** (RFC Process)

Once filed, the issue enters **Technical Validation Phase:**

- **Tag:** `policy-review` (governance policy), `module-review` (infrastructure module), `compliance-review` (GDPR/NIS2 alignment)
- **Timeline:** 7 days for public comment; maintainers review compliance frameworks
- **Discussion:** Technical merit only. No business/product arguments.
- **Decision:** Maintainers decide whether to update policy or close as "working as designed"

### Example Review Comment

```markdown
**@neplusultra-maintainers**: Confirmed. Switzerland ∉ EU per GDPR scope. 
Recommend:
1. Remove "switzerlandnorth" from allowed_eu_regions
2. Create separate `allowed_gdpr_compliant` list (if Swiss region needed for non-GDPR use cases)
3. Update compliance matrix in README

**Change Set:**
- policies/sovereignty/data_residency.rego (line 15-20)
- tests/terraform/sovereignty_enforcement.tftest.hcl (assert on non-EU region)
```

### 3. **Amendment & Enforcement**

If validated, changes are merged by maintainers with:

- **Commit message:** References GitHub issue number and RFC decision
- **Version bump:** Semantic versioning (major.minor.patch)
- **Compliance attestation:** Updated compliance matrix (GDPR Article, NIS2 Article, FADP Section)
- **Test coverage:** New test case covering the fix

### Example Merge Commit

```
commit a7f3d2c9e1b5a3d8c2f6e9a1b3d5f7a8c0e2d4f6

Merge: [ENFORCEMENT] Remove non-EU region from sovereignty guardrail

Fixes #42: data_residency.rego inadvertently allowed Switzerland (non-EU)

Changes:
- Remove "switzerlandnorth" from allowed_eu_regions (GDPR Article 32)
- Restrict to "westeurope", "northeurope", "germanywestcentral" only
- Add test: test_deny_non_eu_region (terraform test)

Compliance:
- GDPR Article 32(1): EU data residency enforcement
- NIS2 Article 21(a): Supply chain security (no non-EU reliance)
- FADP Article 7: Lawfulness (EU jurisdiction only)

Reviewed-by: @neplusultra-maintainers #policy-review
```

---

## Non-Negotiable Boundaries

The following issues **will be closed immediately** (no discussion):

1. **Policy Override Requests**
   - "Can we exempt this resource from encryption?"
   - "Can we allow non-EU region for legacy system?"
   - **Response:** WONTFIX. Exemptions violate sovereignty doctrine.

2. **Governance Theater Proposals**
   - "Can we add soft approval workflows?"
   - "Can we make encryption optional?"
   - **Response:** WONTFIX. Deterministic enforcement only.

3. **Vendor Lock-In Acceptance**
   - "Can we standardize on Azure-only services?"
   - **Response:** WONTFIX. Multi-cloud parameterization is mandatory.

4. **Feature Requests Unrelated to Liquidation**
   - "Add CloudFormation support"
   - "Add Kubernetes policy"
   - **Response:** WONTFIX. Out of scope; file separate RFC if strategic.

---

## Code of Conduct

This repository operates under **technical standards, not social norms.**

- **Respect:** Authoritative architecture decisions (maintainers have final say)
- **Evidence:** All arguments backed by compliance frameworks (GDPR, NIS2, FADP) or technical measurements
- **No advocacy:** Don't argue from product/business preference; argue from compliance/security/efficiency metrics
- **Deterministic:** Decisions reproducible from written specifications

Violations (personal attacks, bad-faith arguments, spam) result in **permanent ban**.

---

## Testing & Validation

All proposed changes **must include test coverage:**

### Terraform Test Requirement

```hcl
# tests/terraform/[your-fix].tftest.hcl

run "test_[issue_number]_fix" {
  command = plan
  
  variables {
    # Reproduce the issue
    primary_region = "..."
  }
  
  # Assert: Fix is applied
  assert {
    condition     = ...
    error_message = "Issue #42 not fixed"
  }
}

run "test_[issue_number]_regression" {
  command = plan
  
  # Assert: Fix doesn't break other guarantees
  assert {
    condition     = ...
    error_message = "Regression: encryption enforcement broken"
  }
}
```

### OPA/Rego Test Requirement

```rego
# policies/[domain]/test_[issue_number].rego

test_issue_42_non_eu_region_denied {
    deny["..."] with input as {
        "resource": {
            "name": "test",
            "location": "us-east-1"  # Non-EU
        }
    }
}

test_issue_42_eu_region_allowed {
    not deny["..."] with input as {
        "resource": {
            "name": "test",
            "location": "eu-west-1"  # EU
        }
    }
}
```

### Run Tests

```bash
# Terraform tests
terraform -chdir=tests/terraform test -verbose

# OPA tests
opa test policies/ -v --format=json
```

---

## Documentation Standards

All changes must include:

1. **Compliance Attestation**
   - Which GDPR articles are addressed?
   - Which NIS2 articles are addressed?
   - Which FADP sections are addressed?

2. **Architecture Decision Record (ADR)**
   - Problem statement
   - Decision made
   - Rationale
   - Consequences (positive & negative)

3. **Example Configuration**
   - Show how to use the new policy/module
   - Include both compliant and non-compliant examples

---

## Versioning

This repository follows **Semantic Versioning**:

- **MAJOR** (e.g., 2.0.0): Breaking changes to policy enforcement (rare)
- **MINOR** (e.g., 1.1.0): New policies or module features (additive, backward-compatible)
- **PATCH** (e.g., 1.0.1): Bug fixes, policy clarifications (no behavioral change)

Versions tag critical decisions:

- `1.0.0` — Initial GDPR/NIS2 enforcement baseline
- `1.1.0` — Added multi-region replication support
- `2.0.0` — (Planned) Kubernetes admission controllers

---

## Recognition

Contributors validated through technical review are listed in:

- **CONTRIBUTORS.md** (architectural decisions, approved friction fixes)
- **Commit attribution** (via GitHub)
- **Issue attribution** (named in RFC discussions)

No financial incentives; recognition is technical credibility only.

---

## Questions?

**Technical Guidance:**
- File an issue with `[QUESTION]` prefix
- Maintainers respond within 5 business days

**Compliance Clarification:**
- File an issue with `[COMPLIANCE]` prefix
- Reference specific GDPR articles, NIS2 articles, or FADP sections

**Security Vulnerability:**
- Do NOT file public issue
- Email security@neplusultra.eu with details
- 90-day disclosure timeline (standard industry practice)

---

## License

By contributing, you agree that your work will be licensed under the **Apache License 2.0** (see [LICENSE](LICENSE)).

You retain copyright; the project gains distribution rights.

---

```
Governance is a legal fiction.
Architecture is law.

29th Regime — Building deterministic sovereignty.
```
