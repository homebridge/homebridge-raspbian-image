# Trigger and Wait for Workflow Action

Starts another workflow in this repo, waits for it to finish, and **fails unless it finished with
success**.

## Usage

```yaml
- name: Trigger and Wait for Stage 2 Workflow
  uses: ./.github/actions/trigger-and-wait-workflow
  with:
    workflow-file: 'create_raspbian_pi-gen.yml'
    ref: 'latest'
    github-token: ${{ github.token }}
    timeout-minutes: '180'
    run-name: "stable:${{ github.run_id }}"
    workflow-fields: |
      release-stream=stable
      publish=true
```

The started workflow must:

- have a `run_name` input, and
- show that input in its own `run-name:`. This is how the action finds the run it started.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `workflow-file` | Yes | - | The workflow file to start |
| `ref` | Yes | `latest` | The branch to run it on |
| `github-token` | Yes | - | A token that may start and read workflow runs (`actions: write`) |
| `run-name` | Yes | - | A unique name for the run, for example `stable:<this run's id>` |
| `timeout-minutes` | No | `30` | The longest time to wait |
| `workflow-fields` | No | - | Inputs for the started workflow, one `key=value` per line |

## Outputs

| Output | Description |
|--------|-------------|
| `workflow-conclusion` | How the run ended: `success`, `failure`, `cancelled`, `timed_out` or `unknown` |
| `run-id` | The id of the run that was started |

## How it works

1. **Start**: `gh workflow run` starts the workflow, with `run_name` and the given fields.
2. **Find**: `gh run list` looks for a run whose name holds `run-name` (up to 1 minute).
3. **Wait**: `wait-for-run.sh` asks for the state of that run every 30 seconds.

## When the step fails

`wait-for-run.sh` ends with code 0 only when the run finished with `success`. The step fails when:

- the workflow could not be started, or the run was not found within 1 minute;
- the run failed, was cancelled, or ended with any result other than `success`;
- the run took longer than `timeout-minutes`;
- the state of the run could not be read 5 times in a row (one short GitHub API problem is retried).

The script is tested in `tests/test-wait-for-run.sh` with a fake `gh` command.
