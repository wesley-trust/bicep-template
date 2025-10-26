# bicep-template

Reusable starting point for Wesley Trust Bicep services. The template mirrors the structure of existing service repositories so new projects inherit pipelines, variable layering, and Pester suites out of the box.

## Getting Started
- Clone this repository as the base for your new service.
- Choose a service moniker (lowercase, no spaces) and service (lowercase with underscores). Example: `containerservices` and `container_services`.
- Rename the following to match your service moniker:
  - `pipeline/service.*.yml`
  - `platform/service.bicep` and `platform/service.bicepparam`
  - `tests/*/service/*` directories and design fixtures under `tests/design/service`
- Search for `service`, `service_module`, and similar placeholders to update names, action group identifiers, and tokens.

## Repository Layout
- `pipeline/` – Azure DevOps pipelines that call the shared dispatcher (`pipeline-dispatcher` -> `pipeline-common`). The deploy pipeline handles production toggles, disaster recovery, environment/region skips, and action-group switches. The tests pipeline runs unit, integration, smoke, and regression suites during CI and on a nightly schedule. The release pipeline publishes semantic versions on `main`.
- `platform/` – Bicep artefacts. `resourcegroup.*` deploys the prerequisite resource group. `service.*` demonstrates a network-focused module (virtual network, route table, network security group) wired to the pipelines with tokenised defaults.
- `vars/` – Layered YAML variables consumed by `pipeline-common`. Includes shared defaults, regional metadata, and per-environment overrides.
- `scripts/` – PowerShell helpers reused across service repos (Pester runner, review helper, semantic-release script, example pre/post hooks).
- `tests/` – Pester suites plus design fixtures. The design JSON files model expected resources, tags, and health checks so tests can assert Azure deployments without hard-coded values. Update the `service` folders with resources relevant to your service.
- `release/` – Placeholder directory used when the release pipeline writes generated notes.

## Token Replacement
Pipelines enable token replacement for `.bicepparam` and design JSON files. Use `#{{ variableName }}` to reference values from the variables layer under `vars/`. Ensure matching entries exist whenever you add new tokens.

## Validation Checklist
- `az bicep build platform/resourcegroup.bicep`
- `az bicep build platform/<service>.bicep`
- `pwsh -File scripts/pester_run.ps1 -PathRoot tests -Type smoke -TestData @{ Name = 'service' } -ResultsFile ./TestResults/local.smoke.xml` (authenticate with Azure beforehand)
- Manually run the deploy pipeline in Azure DevOps for the `dev` environment and confirm the resource group and service deployments succeed.
- Verify the nightly tests pipeline produces NUnit XML artefacts in `TestResults/`.

## Customisation Tips
- Extend `pipeline/service.deploy.pipeline.yml` to add new Bicep modules, adjust dependencies, or wire extra scripts. Follow the schema expected by `pipeline-common` (`type`, `kind`, `scope`, etc.).
- Toggle variable include layers via the `variables` block in `pipeline/service.settings.yml`. Override environment metadata via the optional `environments` array.
- Expand design fixtures under `tests/design` to cover additional resources and health indicators. Smoke suites assert the `health` object; regression and integration suites inspect full resource properties.
- Update `vars/common.yml` and environment/region files to point at the right service connections, naming conventions, address spaces, and peerings for your service.

## References
- `AGENTS.md` – condensed agent handbook tailored to this template.
- `../pipeline-common/docs/CONFIGURE.md` – pipeline-common configuration contract.
- `../pipeline-dispatcher/AGENTS.md` – dispatcher configuration flow.
