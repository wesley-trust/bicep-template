# Agent Handbook

## Mission Overview
- **Repository scope:** Reusable Bicep service template. Provides the complete pipeline and test scaffolding shared by service repos so new projects start from a working baseline.
- **Primary pipeline files:** `pipeline/service.deploy.pipeline.yml` exposes Azure DevOps parameters; `pipeline/service.settings.yml` handles the dispatcher handshake; `pipeline/service.test.pipeline.yml` and `pipeline/service.publish.pipeline.yml` cover CI and semantic releases.
- **Action groups:** `bicep_actions` deploys the resource group before the service Bicep module. `bicep_tests_resource_group` and `bicep_tests_service` execute Pester suites via Azure CLI (`kind: pester`) so the shared templates emit NUnit XML to `TestResults/<actionGroup>_<action>.xml`.
- **Dependencies:** The settings template references `wesley-trust/pipeline-dispatcher`, which in turn locks `wesley-trust/pipeline-common`. Review those repos when diagnosing pipeline behaviour or contracts.

## Repository Layout
- `pipeline/` – Azure DevOps pipeline definitions and dispatcher configuration. After cloning, replace every `service` token (file names, directories, YAML identifiers) with your service (for example `mcp_services`). Use snake_case for pipeline action/test identifiers to keep parity with existing repos.
- `platform/` – Bicep artefacts. `resourcegroup.*` deploys the prerequisite resource group. `service.*` hosts the workload module that you will rename to `<service>.bicep` / `<service>.bicepparam`. Group parameters using the standard headings (Common, Service, Virtual Network, Resource naming, Workload configuration, Monitoring, Storage, Hosting plan, Workload, Role assignments) and perform type conversions (`bool()`, `int()`, `assert`) inside the Bicep file rather than in `.bicepparam`.
- `vars/` – Layered YAML variables (`common`, `regions/*`, `environments/*`). Prefix every workload variable with the service identifier (for example `mcpPlanName`, `mcpMaximumInstanceCount`) and follow CAF abbreviations (`func`, `cae`, `kv`, etc.) together with sequential numbering (`snet-001`, `snet-002`, …).
- `scripts/` – PowerShell helpers invoked from pipeline action groups (Pester runner/review, release automation, sample pre/post hooks).
- `tests/` – Pester suites grouped into `unit`, `integration`, `smoke`, and `regression`. Design fixtures live under `tests/design/resource_group/**` and `tests/design/<service>/**`. Fixture content should be literal values; only use tokens when uniqueness is required (for example the resource-group `deploymentVersion`).

## Pipeline Execution Flow
1. `service.deploy.pipeline.yml` declares runtime parameters (production toggle, DR invocation, environment/region skips, action + test switches) before extending the settings template.
2. `service.settings.yml` references the dispatcher repository and extends `/templates/pipeline-configuration-dispatcher.yml@PipelineDispatcher`.
3. The dispatcher merges defaults, then forwards the composed `configuration` object into `pipeline-common/templates/main.yml`.
4. `pipeline-common` orchestrates initialise, validation, optional review, and deploy stages while loading variables and executing the defined action groups. See `pipeline-common/AGENTS.md` and `docs/CONFIGURE.md` for the full contract.

## Customisation Workflow
1. **Define the service** – choose a CAF-compliant abbreviation (for example `mcp`, `cae`, `kv`). Use it consistently for file names, variable prefixes, and identifiers.
2. **Rename template artefacts** – replace `service` with your service throughout `pipeline/`, `platform/`, `tests/`, and `vars/`. Ensure directories mirror the final naming (`tests/unit/<service>/`, `tests/design/<service>/`, etc.).
3. **Update variables** – in `vars/common.yml` (and layered regional/environment files) prefix all workload variables with the service and follow the sequential numbering already in use (`snet-001`, `snet-002`, …). Embed CAF resource abbreviations in names (for example `func-`, `plan-`, `st`, `law`, `appi`).
4. **Shape the Bicep module** – keep parameter sections grouped under the standard comment headings. Accept string tokens from `.bicepparam` and convert them within the Bicep using local variables. Use `assert` statements to enforce numeric limits or invariants.
5. **Refresh `.bicepparam`** – mirror the section headings used in the Bicep module. Token replacements should reference the service-prefixed variable names defined in `vars/`.
6. **Adjust pipelines** – rename action groups (`bicep_tests_<service>`) and update token replacement patterns so they target the new directories. Stick to snake_case action names and honour the dispatcher schema (`type`, `scope`, `templatePath`, etc.).
7. **Extend tests and design fixtures** – copy the template structure, replace filenames with CAF abbreviations, hard-code expected tags/names/health values, and only use tokens when values must vary per run. Match `TestData.Name` values to the service directories (for example `mcp_services`).
8. **Validate naming** – confirm all resource names comply with both local conventions and the Cloud Adoption Framework. Run `az bicep build` (or equivalent) and the Pester suites before raising a PR.

## Testing & Validation
- `scripts/pester_run.ps1` installs required modules, authenticates using the federated token presented by Azure CLI, and runs Pester with NUnit output. The script expects `-PathRoot`, `-Type`, and `-TestData.Name`; ensure the name matches the service directory (for example `@{ Name = 'mcp_services' }`).
- Smoke suites validate the `health` object surfaced by each design file, providing a readiness signal without broad property asserts. Expand the health payload for additional checks.
- Review stage relies on pipeline-common Bicep what-if output. `scripts/pester_review.ps1` ships as an optional helper if you wire in review actions.
- CI action groups in `<service>.test.pipeline.yml` enable `variableOverridesEnabled` with `dynamicDeploymentVersionEnabled: true` to isolate concurrent executions.
- Use `az bicep build platform/<service>.bicep` and `platform/resourcegroup.bicep` locally to validate syntax before pushing changes, and resolve compiler warnings (CAF assertions, naming) before committing.

## Operational Notes
- Document behavioural changes (parameters, action groups, dependency updates) in `README.md` or inline comments so future contributors understand the contract.
- When dispatcher defaults need updates (service connections, pools, approvals), coordinate changes in the dispatcher repo to keep consumers aligned.
- The preview tooling in `pipeline-common/tests` validates the generated Azure DevOps definitions before merging.

## References
- `pipeline-common/AGENTS.md` and `docs/CONFIGURE.md` – shared pipeline stages and configuration schema.
- `pipeline-dispatcher/AGENTS.md` – explains configuration merging between consumers and shared templates.
