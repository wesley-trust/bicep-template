# Agent Handbook

## Mission Overview
- **Repository scope:** Reusable Bicep service template. Provides the complete pipeline and test scaffolding shared by service repos so new projects start from a working baseline.
- **Primary pipeline files:** `pipeline/service.deploy.pipeline.yml` exposes Azure DevOps parameters; `pipeline/service.settings.yml` handles the dispatcher handshake; `pipeline/service.tests.pipeline.yml` and `pipeline/service.release.pipeline.yml` cover CI and semantic releases.
- **Action groups:** `bicep_actions` deploys the resource group before the service Bicep module. `bicep_tests_resource_group` and `bicep_tests_service` execute Pester suites via Azure CLI (`kind: pester`) so the shared templates emit NUnit XML to `TestResults/<actionGroup>_<action>.xml`.
- **Dependencies:** The settings template references `wesley-trust/pipeline-dispatcher`, which in turn locks `wesley-trust/pipeline-common`. Review those repos when diagnosing pipeline behaviour or contracts.

## Repository Layout
- `pipeline/` – Azure DevOps pipeline definitions and dispatcher configuration. Rename `service.*` files when cloning the template.
- `platform/` – Bicep artefacts. `resourcegroup.*` deploys the prerequisite resource group; `service.*` contains the service sample wired to the pipelines.
- `vars/` – Layered YAML variables (`common`, `regions/*`, `environments/*`). Dispatcher include flags load these files before each stage.
- `scripts/` – PowerShell helpers invoked from pipeline action groups (Pester runner/review, release automation, sample pre/post hooks).
- `tests/` – Pester suites grouped into `unit`, `integration`, `smoke`, and `regression`. Matching design fixtures live under `tests/design/resource_group/**` and `tests/design/service/**`.

## Pipeline Execution Flow
1. `service.deploy.pipeline.yml` declares runtime parameters (production toggle, DR invocation, environment/region skips, action + test switches) before extending the settings template.
2. `service.settings.yml` references the dispatcher repository and extends `/templates/pipeline-configuration-dispatcher.yml@PipelineDispatcher`.
3. The dispatcher merges defaults, then forwards the composed `configuration` object into `pipeline-common/templates/main.yml`.
4. `pipeline-common` orchestrates initialise, validation, optional review, and deploy stages while loading variables and executing the defined action groups. See `pipeline-common/AGENTS.md` and `docs/CONFIGURE.md` for the full contract.

## Customisation Points
- Adjust action groups in `service.deploy.pipeline.yml` to add new Bicep modules, tweak scripts, or alter dependencies. Honour the schema expected by `pipeline-common` (`type`, `scope`, `templatePath`, etc.).
- Enable/disable variable layers via the `variables` block in `service.settings.yml` or override environment metadata through the optional `environments` array.
- Populate `platform/service.bicep` and `platform/service.bicepparam` with your module logic after cloning.
- Extend design fixtures and tests under `tests/` to reflect added resources. Keep folder names aligned with the `TestData.Name` values passed by the pipelines.

## Testing & Validation
- `scripts/pester_run.ps1` installs required modules, authenticates using the federated token presented by Azure CLI, and runs Pester with NUnit output. The script expects `-PathRoot`, `-Type`, and `-TestData.Name`.
- Smoke suites validate the `health` object surfaced by each design file, providing a readiness signal without broad property asserts. Expand the health payload for additional checks.
- Review stage relies on pipeline-common Bicep what-if output. `scripts/pester_review.ps1` ships as an optional helper if you wire in review actions.
- CI action groups in `service.tests.pipeline.yml` enable `variableOverridesEnabled` with `dynamicDeploymentVersionEnabled: true` to isolate concurrent executions.
- Use `az bicep build platform/service.bicep` and `platform/resourcegroup.bicep` locally to validate syntax before pushing changes.

## Operational Notes
- Document behavioural changes (parameters, action groups, dependency updates) in `README.md` or inline comments so future contributors understand the contract.
- When dispatcher defaults need updates (service connections, pools, approvals), coordinate changes in the dispatcher repo to keep consumers aligned.
- The preview tooling in `pipeline-common/tests` validates the generated Azure DevOps definitions before merging.

## References
- `pipeline-common/AGENTS.md` and `docs/CONFIGURE.md` – shared pipeline stages and configuration schema.
- `pipeline-dispatcher/AGENTS.md` – explains configuration merging between consumers and shared templates.
