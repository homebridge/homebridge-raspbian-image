#!/usr/bin/env bash
# shellcheck disable=SC2016  # single quotes are meant: that text must reach the script under test as it is
# Rules for the workflow files.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

WORKFLOWS="$REPO/.github/workflows"
ACTIONS="$REPO/.github/actions"

# every "uses:" line of every workflow and local action, as "file:line: target"
uses() {
  grep -rnE '^\s*(-\s+)?uses:' "$WORKFLOWS" "$ACTIONS" --include='*.yml' \
    | sed -E "s#^$REPO/##; s/^([^:]+:[0-9]+):\s*(-\s+)?uses:\s*['\"]?([^'\" ]+)['\"]?.*/\1: \3/"
}

# An action from outside GitHub and the Homebridge organisation runs with this repo's tokens.
# A tag or a branch name can be moved to other code by its owner. A full commit id can not.
while read -r where target; do
  case "$target" in
    ./* | actions/* | homebridge/*) continue ;;
  esac
  if [[ "$target" =~ @[0-9a-f]{40}$ ]]; then
    ok "outside action is named by commit: $target"
  else
    fail "outside action is named by commit: $target" "$where"
  fi
done < <(uses)

# the pull request workflow runs code from pull requests, so there every action is named by commit
while read -r where target; do
  case "$where" in *workflows/ci.yml*) ;; *) continue ;; esac
  if [[ "$target" =~ @[0-9a-f]{40}$ ]]; then
    ok "ci.yml: named by commit: $target"
  else
    fail "ci.yml: named by commit: $target" "$where"
  fi
done < <(uses)

isnt "no workflow uses the copy_file_to_another_repo action" grep -rq 'copy_file_to_another_repo' "$WORKFLOWS"

STAGE3="$WORKFLOWS/release-stage-3_package_release.yml"
same "every token made for another repo names the rights it needs" \
  "$(grep -c 'uses: actions/create-github-app-token' "$STAGE3")" "$(grep -c 'permission-contents: write' "$STAGE3")"

# The rights of each job, and how values reach shell lines. Read from the YAML itself.
python3 - "$WORKFLOWS" "$ACTIONS" > "$W/workflow-facts" <<'PYTHON'
import glob, os, sys, yaml

workflows, actions = sys.argv[1], sys.argv[2]

for path in sorted(glob.glob(os.path.join(workflows, "*.yml"))):
    name = os.path.basename(path)
    data = yaml.safe_load(open(path))
    print(f"top {name} {data.get('permissions', 'MISSING')!r}")
    for job_id, job in data["jobs"].items():
        rights = job.get("permissions", {})
        text = ",".join(f"{key}:{value}" for key, value in sorted(rights.items())) or "none"
        print(f"job {name} {job_id} {text}")
        for index, step in enumerate(job.get("steps", [])):
            if "${{" in str(step.get("run", "")):
                print(f"expr {name} {job_id} step {index + 1} ({step.get('name', '')})")

for path in sorted(glob.glob(os.path.join(actions, "*", "action.yml"))):
    data = yaml.safe_load(open(path))
    for index, step in enumerate(data["runs"]["steps"]):
        if "${{" in str(step.get("run", "")):
            print(f"expr {os.path.basename(os.path.dirname(path))} step {index + 1} ({step.get('name', '')})")
PYTHON
same "the workflow files could be read" "$?" "0"

# every workflow starts with no rights at all; jobs then ask for what they need
same "every workflow gives no rights by default" "$(grep -c '^top ' "$W/workflow-facts")" "$(grep -c "^top .* {}$" "$W/workflow-facts")"

# job_rights <workflow file> <job> <expected rights>
job_rights() {
  same "$1 / $2 has these rights: $3" "$(sed -n "s/^job $1 $2 //p" "$W/workflow-facts")" "$3"
}
job_rights ci.yml lint "contents:read"
job_rights ci.yml actionlint "contents:read"
job_rights ci.yml tests "contents:read"
job_rights release-stage-1_update_dependencies.yml define-matrix "none"
job_rights release-stage-1_update_dependencies.yml update-dependencies "actions:write,contents:read"
job_rights create_raspbian_pi-gen.yml tag "contents:read"
job_rights create_raspbian_pi-gen.yml determine_package_versions "contents:read"
job_rights create_raspbian_pi-gen.yml build_images "contents:read"
job_rights create_raspbian_pi-gen.yml trigger-stage-3 "actions:write,contents:read"
job_rights release-stage-3_package_release.yml download-and-prepare "actions:read,contents:read"
job_rights release-stage-3_package_release.yml create-release "contents:read"
job_rights release-stage-3_package_release.yml publish-to-registry "contents:read"
job_rights release-stage-3_package_release.yml notify-discord "none"
job_rights labeler.yml labeler "contents:read,pull-requests:write"
job_rights pr-labeler.yml label "contents:read,pull-requests:write"
job_rights stale.yml stale "issues:write,pull-requests:write"
job_rights wiki-change-notification.yml notify "none"
same "every job is in the list above" "$(grep -c '^job ' "$W/workflow-facts")" "17"

# A value pasted into a shell line becomes shell code. Values must come in through "env:".
same "no shell line has a \${{ }} value pasted into it" "$(grep '^expr ' "$W/workflow-facts")" ""

isnt "no workflow uses the personal access token GH_TOKEN" grep -rq 'secrets\.GH_TOKEN' "$WORKFLOWS" "$ACTIONS"

# scripts/publish-imager-json.sh against a stand-in for homebridge.io
PUBLISH="$REPO/scripts/publish-imager-json.sh"
git init -q --bare -b source "$W/site.git"
git clone -q "$W/site.git" "$W/seed" 2> /dev/null
( cd "$W/seed" && mkdir -p src/public && echo '{"os_list":[{"name":"old"}]}' > src/public/rpi-image-repo.json && echo page > src/public/index.html \
  && git add -A && git -c user.name=t -c user.email=t@example.invalid commit -q -m first && git push -q origin HEAD:source )
git clone -q --branch source "$W/site.git" "$W/checkout"
echo '{"os_list":[{"name":"new"}]}' > "$W/new.json"

is "pushes the new file" "$PUBLISH" "$W/checkout" "$W/new.json" v2.0.26
same "the pushed file is the new one" "$(git -C "$W/site.git" show source:src/public/rpi-image-repo.json)" '{"os_list":[{"name":"new"}]}'
same "the commit changes that one file only" "$(git -C "$W/site.git" show --name-only --format= source)" "src/public/rpi-image-repo.json"
same "the commit message names the release" "$(git -C "$W/site.git" log -1 --format=%s source)" "New Homebridge Raspbian Image Release v2.0.26"
is "a second run with the same file passes" "$PUBLISH" "$W/checkout" "$W/new.json" v2.0.26
same "and makes no new commit" "$(git -C "$W/site.git" rev-list --count source)" "2"

echo untracked > "$W/checkout/src/public/other.txt"
echo changed > "$W/checkout/src/public/index.html"
echo '{"os_list":[{"name":"newer"}]}' > "$W/new.json"
is "pushes again when the file changed" "$PUBLISH" "$W/checkout" "$W/new.json" v2.0.27
same "other changed files in the checkout are not pushed" "$(git -C "$W/site.git" show --name-only --format= source)" "src/public/rpi-image-repo.json"

echo '{"os_list":[]}' > "$W/empty.json"
isnt "stops on a list with no images" "$PUBLISH" "$W/checkout" "$W/empty.json" v2.0.28
echo 'not json' > "$W/broken.json"
isnt "stops on a file that is not JSON" "$PUBLISH" "$W/checkout" "$W/broken.json" v2.0.28
mkdir -p "$W/not-the-site"
isnt "stops when the folder is not a checkout of the website" "$PUBLISH" "$W/not-the-site" "$W/new.json" v2.0.28

finish
