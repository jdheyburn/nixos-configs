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

    for pod in $(kubectl get pods --no-headers -o custom-columns=":metadata.name"  --field-selector spec.nodeName=$node); do
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
        if [ $value != "null" ]; then
            echo $file
            echo $value
        fi
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

# Third-party functions

##### fzf #### (https://github.com/junegunn/fzf)

# Use fd (https://github.com/sharkdp/fd) instead of the default find
# command for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
function _fzf_compgen_path() {
    fd --hidden --follow --exclude ".git" . "$1"
}

# Use fd to generate the list for directory completion
function _fzf_compgen_dir() {
    fd --type d --hidden --follow --exclude ".git" . "$1"
}
