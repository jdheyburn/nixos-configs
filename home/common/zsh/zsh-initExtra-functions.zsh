# GitCommitMsg - adds the JIRA ticketed branch named to the commit message
unalias gcmsg # remove the existing gcmsg
function gcmsg() {
    setopt local_options BASH_REMATCH

    local msg=$@
    if [ -z "$msg" ]; then
        echo "gcmsg - no message was provided"
        return 1
    fi

    local curr_branch=$(git_current_branch)
    local regex="^[A-Z]{2,}\-[0-9]+"
    if [[ $curr_branch =~ $regex ]]; then
        local ticket="${BASH_REMATCH[1]}"
        local msg="$ticket - $msg"
    fi

    git commit -m "$msg"
}

# makechangedir - takes in a dir to create and then cd into
function mc() {
    local dir=$1
    if [ -z "$dir" ]; then
        echo "mc - no dir was provided"
        return 1
    fi

    mkdir -p "$dir"
    cd "$dir"
}

# SearchDirectory - recursive search through the targeted dir for the text in any file
function sdd() {
    local searchTerm=$1
    local searchDir=$2
    if [ -z "$searchTerm" ]; then
        echo "sd - No search term provided"
        return 1
    fi
    if [ -z "$searchDir" ]; then
        echo "sd - No dir specified - defaulting to current dir"
        searchDir="."
    fi

    grep --ignore-case --files-with-matches --recursive --no-messages --exclude-dir=".terraform" $searchTerm $searchDir
}

# UnZip - unzip the archive into a dir at the same location with the archive name
function uz() {
    unzip "$1" -d "${1##*/}"
}

# Change AWS instance type by hostname
function modify-aws-instance-type() {
    local hostname=$1
    if [ -z $hostname ]; then
        echo "ERR: hostname not provided, usage:"
        echo "  modify-aws-instance-type HOSTNAME INSTANCE_TYPE"
        return 1
    fi
    local instance_type=$2
    if [ -z $instance_type ]; then
        echo "ERR: instance_type not provided, usage:"
        echo "  modify-aws-instance-type HOSTNAME INSTANCE_TYPE"
        return 1
    fi

    local describe_instance=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$hostname")

    local instance_id=$(echo "$describe_instance" | jq -r '.Reservations[].Instances[0].InstanceId')
    if [ -z $instance_id ]; then
        echo "ERR: InstanceId not found for $hostname"
        return 1
    fi

    echo "$hostname -> $instance_id"

    local curr_instance_type=$(echo "$describe_instance" | jq -r '.Reservations[].Instances[0].InstanceType')
    if [[ "$instance_type" == "$curr_instance_type" ]]; then
        echo "$hostname instance type is already $instance_type"
        return 0
    fi
    echo "$hostname instance_type: $curr_instance_type"

    local validate_instance_type=$(aws ec2 describe-instance-types --instance-types $instance_type | jq -r '.InstanceTypes[0].InstanceType')
    if [[ "$validate_instance_type" != "$instance_type" ]]; then
        echo "ERR: $instance_type is not a valid instance type"
        return 1
    fi

    local state=$(echo "$describe_instance" | jq -r '.Reservations[].Instances[0].State.Name')
    if [[ "$state" != "stopped" ]]; then
        echo "stopping $hostname"
        local state=$(aws ec2 stop-instances --instance-ids $instance_id | jq -r '.StoppingInstances[0].CurrentState.Name')
        while [[ "$state" != "stopped" ]]; do
            echo "waiting for $hostname / $instance_id state = 'stopped', currently $state"
            sleep 5
            local state=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$hostname" | jq -r '.Reservations[].Instances[0].State.Name')
        done
    fi

    echo "$hostname stopped. modifying instance type to $instance_type"

    if ! aws ec2 modify-instance-attribute --instance-id $instance_id --instance-type $instance_type; then
        return 1
    fi

    echo "starting $hostname"

    local state=$(aws ec2 start-instances --instance-ids $instance_id | jq -r '.StartingInstances[0].CurrentState.Name')
    echo "$hostname is in $state state"
    return 0
}

# For the given hostname, output the IPs and the AZs they are in
function get-az-ips-for-hostname() {
    local hostname=$1
    if [ -z $hostname ]; then
        echo "ERR: hostname not provided, usage:"
        echo "  get-az-ips-for-hostname HOSTNAME"
        return 1
    fi

    local ips=$(dig $hostname | grep -A3 "ANSWER SECTION" | tail -3 | rev | cut -d " " -f1 | rev | paste -s -d "," -)

    # Optional
    local region=$2
    if [ ! -z $region ]; then
        local ipDetails=$(AWS_REGION=$region aws ec2 describe-network-interfaces --filters Name=addresses.private-ip-address,Values=$ips)
    else
        local ipDetails=$(aws ec2 describe-network-interfaces --filters Name=addresses.private-ip-address,Values=$ips)
    fi

    # https://www.starkandwayne.com/blog/bash-for-loop-over-json-array-using-jq/
    for row in $(echo $ipDetails | jq -r '.NetworkInterfaces[] | @base64'); do
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }
        local az=$(_jq '.AvailabilityZone')
        local ip=$(_jq '.PrivateIpAddress')
        echo "$az - $ip"
    done
}

# For the given ingress, discover the domain name for it and output the IPs and the AZs they are in
function get-az-ips-for-ingress() {
    local ingress=$1
    if [ -z $ingress ]; then
        echo "ERR: ingress not provided, usage:"
        echo "  get-az-ips-for-ingress INGRESS_NAME"
        return 1
    fi

    # Optional
    local region=$2

    local hostname=$(kubectl get services $ingress --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')

    get-az-ips-for-hostname $hostname $region
}

function restart_bluetooth() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        blueutil --power 0 && blueutil --power 1
    else
        echo "restart_bluetooth not implemented for $OSTYPE"
        return 1
    fi
}

# For a given K8s node, output what Redis pods running on there and what their role is
function get-redis-on-node() {
    local node=$1

    if [ -z $node ]; then
        echo "ERR: node not provided, usage:"
        echo "  get-redis-on-node NODE_NAME"
        return 1
    fi

    for pod in $(kubectl get pods --no-headers -o custom-columns=":metadata.name" --field-selector spec.nodeName=$node -l redis-component!=sentinel); do
        role=$(kubectl exec -it $pod -c redis -- sh -c 'redis-cli --no-auth-warning -a $AUTH role | grep -E "(master|slave)"')
        echo "$pod - $role"
    done
}

# Outputs info I use to troubleshoot k8s nodes
function get-k8s-nodes() {
    kubectl get nodes -o custom-columns="NAME:metadata.name,STATUS:status.conditions[-1].type,IP_ADDRESS:status.addresses[?(@.type == 'InternalIP')].address,ZONE:metadata.labels.topology\.kubernetes\.io/zone,INSTANCE_TYPE:metadata.labels.node\.kubernetes\.io/instance-type,CREATED:metadata.creationTimestamp" $@
}

# Get the pods running on a particular node
function get-pods-on-node() {
    local node=$1
    kubectl get pods -o wide --field-selector spec.nodeName=$node
}

# Exec into a pod - because I can never remember the command for it
function exec-pod() {
    kubectl exec -it $1 -- sh
}

# Loop over each values.yaml file and retrieve the value for the given key if it is available
function get-values() {
    local app=$1
    if [ -z $app ]; then
        echo "ERR: app not provided, usage:"
        echo "  get-values APP KEY"
        return 1
    fi

    local key=$2
    if [ -z $key ]; then
        echo "ERR: key not provided, usage:"
        echo "  get-values APP KEY"
        return 1
    fi

    for file in apps/$app/values/**/values.yaml; do
        local value=$(yq $key $file)
        if [ $value = "null" ]; then
            continue
        fi

        echo $file
        echo $value
        echo
    done
}

# HeadPhones
function hp() {
    local id="94-db-56-84-69-49"
    local action=$1

    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "hp not implemented for $OSTYPE"
        return 1
    fi

    if [[ $action == "c" ]]; then
        blueutil --connect $id
    elif [[ $action == "d" ]]; then
        blueutil --disconnect $id
    else
        echo "hp - unknown action: $action"
        return 1
    fi
}

# start squeezelite

function squeezeme() {

    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "squeezeme not implemented for $OSTYPE"
        return 1
    fi

    local id="94-db-56-84-69-49"
    local headphones="WH-1000XM3"

    if ps -ef | grep squeezelite | grep -v grep; then
        killall squeezelite
    fi

    local headphones_connected=$(blueutil --is-connected $id)

    if [ $headphones_connected = "0" ]; then
        hp c
    fi

    local headphones_id=$(squeezelite -l | grep $headphones | awk '{print $1}')

    squeezelite -n macos -d all=info -o $headphones_id &
}

# Better diff
function diff() {

    local file1=$1
    local file2=$2

    # cat may be aliased to bat
    /usr/bin/diff -u $file1 $file2 | diff-so-fancy | cat
}

# GitTop: navigate to root of git repo  - https://blog.meain.io/2023/navigating-around-in-shell/#navigating-to-project-root
function gt() {
    cd "$(git rev-parse --show-toplevel 2>/dev/null)"
}

# worktree-pr: checkout a GitHub PR into an isolated git worktree
# Usage: worktree-pr <PR-number-or-URL>
worktree-pr() {
  local pr_input="$1"
  local pr_number

  if [[ -z "$pr_input" ]]; then
    echo "Usage: worktree-pr <PR-number-or-URL>" >&2
    return 1
  fi

  # Accept PR number or full GitHub URL
  if [[ "$pr_input" =~ /pull/([0-9]+) ]]; then
    pr_number="${match[1]}"
  else
    pr_number="$pr_input"
  fi

  # Derive upstream repo slug (e.g. valkey-io/valkey-operator) from remote
  local upstream_url
  upstream_url=$(git remote get-url upstream 2>/dev/null || git remote get-url origin)
  local upstream_repo
  upstream_repo=$(echo "$upstream_url" | sed 's|.*github\.com[:/]\(.*\)\.git|\1|')

  # Fetch PR metadata via gh CLI
  local pr_json
  pr_json=$(gh pr view "$pr_number" --repo "$upstream_repo" \
    --json headRefName,headRepositoryOwner,state,mergeCommit) || return 1

  local branch_name owner state merge_commit
  branch_name=$(echo "$pr_json" | jq -r '.headRefName')
  owner=$(echo "$pr_json"       | jq -r '.headRepositoryOwner.login')
  state=$(echo "$pr_json"       | jq -r '.state')
  merge_commit=$(echo "$pr_json"| jq -r '.mergeCommit.oid // empty')

  local worktree_name="pr-${pr_number}-${branch_name//\//-}"
  local worktree_path=".worktrees/${worktree_name}"

  if [[ -d "$worktree_path" ]]; then
    echo "Worktree already exists at ${worktree_path}"
    return 0
  fi

  if [[ "$state" == "MERGED" ]]; then
    git fetch upstream
    git worktree add "$worktree_path" "$merge_commit"
    echo "Merged PR — detached HEAD at ${merge_commit:0:7}"
  else
    # Add fork remote if it doesn't exist
    if ! git remote get-url "$owner" &>/dev/null; then
      local repo_name
      repo_name=$(basename "$upstream_url" .git)
      local fork_url="git@github.com:${owner}/${repo_name}.git"
      echo "Adding remote: ${owner} -> ${fork_url}"
      git remote add "$owner" "$fork_url"
    fi
    git fetch "$owner" "$branch_name"
    git worktree add "$worktree_path" -b "$worktree_name" "${owner}/${branch_name}"
    echo "Worktree ready at ${worktree_path}"
    echo "Push changes back with: git push ${owner} HEAD:${branch_name}"
  fi

  cd $worktree_path
}

# worktree-clean: clean up PR worktrees that are no longer needed
# Usage: worktree-clean [--all] [--merged] [--closed]
worktree-clean() {
  local filter_mode="$1"
  local worktrees_dir=".worktrees"

  if [[ ! -d "$worktrees_dir" ]]; then
    echo "No worktrees directory found at ${worktrees_dir}"
    return 0
  fi

  # Derive upstream repo slug
  local upstream_url
  upstream_url=$(git remote get-url upstream 2>/dev/null || git remote get-url origin)
  local upstream_repo
  upstream_repo=$(echo "$upstream_url" | sed 's|.*github\.com[:/]\(.*\)\.git|\1|')

  local found_any=0
  local removed_count=0

  for worktree_path in "$worktrees_dir"/pr-*; do
    [[ ! -d "$worktree_path" ]] && continue

    local worktree_name=$(basename "$worktree_path")

    # Extract PR number from pr-123-branch-name format
    if [[ "$worktree_name" =~ ^pr-([0-9]+)- ]]; then
      local pr_number="${match[1]}"
    else
      echo "Skipping ${worktree_name} (unexpected format)"
      continue
    fi

    # Fetch PR state
    local pr_json state
    pr_json=$(gh pr view "$pr_number" --repo "$upstream_repo" --json state 2>/dev/null)

    if [[ $? -ne 0 ]]; then
      echo "⚠️  ${worktree_name}: PR #${pr_number} not found (may have been deleted)"
      found_any=1

      if [[ "$filter_mode" != "--merged" && "$filter_mode" != "--closed" ]]; then
        echo -n "   Remove this worktree? [y/N] "
        read response
        if [[ "$response" =~ ^[Yy]$ ]]; then
          git worktree remove "$worktree_path" --force
          echo "   ✓ Removed"
          ((removed_count++))
        fi
      fi
      continue
    fi

    state=$(echo "$pr_json" | jq -r '.state')

    local should_prompt=0
    local status_icon=""

    case "$state" in
      MERGED)
        status_icon="✓"
        [[ -z "$filter_mode" || "$filter_mode" == "--all" || "$filter_mode" == "--merged" ]] && should_prompt=1
        ;;
      CLOSED)
        status_icon="✗"
        [[ -z "$filter_mode" || "$filter_mode" == "--all" || "$filter_mode" == "--closed" ]] && should_prompt=1
        ;;
      OPEN)
        status_icon="●"
        [[ "$filter_mode" == "--all" ]] && should_prompt=1
        ;;
      *)
        status_icon="?"
        ;;
    esac

    if [[ $should_prompt -eq 1 ]]; then
      found_any=1
      echo "${status_icon} ${worktree_name}: PR #${pr_number} (${state})"
      echo -n "   Remove this worktree? [y/N] "
      read response
      if [[ "$response" =~ ^[Yy]$ ]]; then
        git worktree remove "$worktree_path" --force
        echo "   ✓ Removed"
        ((removed_count++))
      fi
    fi
  done

  if [[ $found_any -eq 0 ]]; then
    if [[ -n "$filter_mode" ]]; then
      echo "No worktrees found matching filter: ${filter_mode}"
    else
      echo "No merged or closed PR worktrees found."
      echo ""
      echo "Usage: worktree-clean [--all] [--merged] [--closed]"
      echo "  (no args)  Show merged & closed PRs only"
      echo "  --all      Show all PR worktrees including open ones"
      echo "  --merged   Show only merged PRs"
      echo "  --closed   Show only closed PRs"
    fi
  else
    echo ""
    echo "Removed ${removed_count} worktree(s)"
  fi
}
