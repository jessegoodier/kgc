#!/bin/bash

## This is a function. use it by sourcing it in your shell and calling one of the functions
## source .kgc.sh
## run it without and argument to get the current namespace
## kgc all will run it against all namespaces.
## Currently maintained here:
## <https://github.com/jessegoodier/kgc/>

# The name kgc is because it is like the alias `kgp` for kubectl get pods
# kgc is to k get containers
# it also prints related errors to help identify the cause of failing containers
# Add to your profile by sourcing this file in your .zshrc or .bashrc
# source ~/.kgc.sh
# You may have an alias for kgc already, if so, you can unalias it before sourcing this file
# unalias kgc 2> /dev/null
# There are not a ton of comments in this file, but any AI can explain it, whih I find to be simple to do and cleaner than adding comments
# I attempted to make the output as clean as possible, but it is not perfect, for example, the space before the pod when not using `kgc all` 

function kgc {
# k get containers, show failures
# this fucntion is not indented, look for the /end-kgc comment

# Define color variables
RED="\033[0;31m"
YELLOW="\033[1;33m"
WHITE="\033[1;37m"
CYAN="\033[0;36m"
RESET="\033[0m"


# Initialize argument variables
a_argument=false
n_argument=""
hide_pod_errors=false
hide_replicaset_errors=false

# Check for -h or --help before getopts loop
if [[ " $* " =~ (--help|-h) ]]; then
    echo "Usage: $(basename $0) [namespace] OR [OPTION]..."
    echo "Examples:"
    echo "kgc -n kube-system - will get all pods in the kube-system namespace"
    echo "kgc with no arguments will get all containers in the current context's namespace"
    echo "Available options:"
    echo "  -a or -A       Get containers in all namespaces"
    echo "  -n namespace   Specific namespace"
    echo "  -p             Hide pod error list"
    echo "  -r             Hide replicaset error list"
    echo "  -h or --help   Display this help and exit"
    return
fi

# Parse arguments if n is passed it requires a namespace
while getopts ":aAn:pr" opt; do
  case ${opt} in
    a | A )
      a_argument=true  # Set to true when -a or -A is triggered
      ;;
    n )
      n_argument=$OPTARG
      ;;
    p )
      hide_pod_errors=true
      ;;
    r )
      hide_replicaset_errors=true
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

# get the namespace from the first argument, otherwise use the current namespace
if [[ -z "$n_argument" ]]; then
  namespace_arg=$1
else
  namespace_arg=$n_argument
fi

issue_counter=0

# use current context namspace if nothing else is passed
if [[ -z "$namespace_arg" ]]; then
  namespace=$(kubectl config view --minify --output 'jsonpath={..namespace}')
else
  namespace=$namespace_arg
fi

if [[ $a_argument == true ]]; then
  namespace_arg="all"
fi

declare -a current_failures

namespace_column=0

# Get all pods in the namespace
if [[ $namespace_arg == "all" ]]; then
  pods_json=$(kubectl get pods -o json -A| jq '.items[] | {namespace: .metadata.namespace, name: .metadata.name, status: .status.phase, containers: .status.containerStatuses}')
  namespace_list=($(echo "$pods_json" | jq -r '.namespace'))

  # Figure out the table spacing with namespace
  for namespace_name in "${namespace_list[@]}"; do
    namespace_chars=${#namespace_name}
    if (( namespace_chars > namespace_column )); then
      namespace_column=$namespace_chars
    fi
  done

else
  pods_json=$(kubectl get pods -n "$namespace" -o json | jq '.items[] | {namespace: .metadata.namespace, name: .metadata.name, status: .status.phase, containers: .status.containerStatuses}')
fi

pod_list=($(echo "$pods_json" | jq -r '.name'))

# Figure out the table spacing
pod_column=4 # needs to be at least as long as the word "Pod"
for pod_name in "${pod_list[@]}"; do
  pod_chars=${#pod_name}
  if (( pod_chars > pod_column )); then
    pod_column=$pod_chars
  fi
done

# find the longest container name for the column width
container_list=($(echo "$pods_json" | jq -r 'select(.containers != null) | .containers[].name'))
container_name_column=15 # needs to be at least as long as the words "Container Name"
for container_name in "${container_list[@]}"; do
  column_width=${#container_name}
  if (( column_width > container_name_column )); then
    container_name_column=$column_width
  fi
done

# find the longest container image name for the column width
container_image_column=6 # needs to be at least as long as the words "Image"
container_image_list=($(echo "$pods_json" | jq -r 'select(.containers != null) | .containers[].image'))

for container_image_name in "${container_image_list[@]}"; do
  container_image_short=${container_image_name##*/}
  container_image_width=${#container_image_short}
  if (( container_image_width > container_image_column )); then
    container_image_column=$container_image_width
  fi
done
# Set a max width for the container image column
if (( container_image_column >45 )); then
  container_image_column=45
fi

if [[ ${#pod_list} -gt 0 ]]; then
  print_table_header
else
  printf "\033[0;33mNo pods found in %s namespace${RESET}\n" "$namespace"
fi

for pod in "${pod_list[@]}"; do
  num_containers_in_this_pod=$(echo "$pods_json" | jq -r ".| select(.name == \"$pod\") |.containers| length" || echo 0)
  if [[ $namespace_arg == "all" ]]; then
    namespace=$(echo "$pods_json" | jq -r ".| select(.name == \"$pod\") |.namespace")
    ns_col=$namespace
  else
    ns_col=""
  fi

  if [ "$num_containers_in_this_pod" -lt 1 ]; then
    ((issue_counter+=1))
    printf "${RED}%-${namespace_column}s %-${pod_column}s %-${container_name_column}s %-${container_image_column}s %-${status_column}s${RESET}\n" "$ns_col" "$pod" "-" "-" "false ($issue_counter)"
    current_failures+=("$pod"/"$namespace")
    continue
  fi

  containers_in_this_pod_json=$(echo "$pods_json" | jq -r ".| select(.name == \"$pod\") |.containers[]")
  containers_in_this_pod_list=($(echo "$containers_in_this_pod_json" | jq -r ".name"))
  for container_name in "${containers_in_this_pod_list[@]}"; do

    container_ready=$(echo "$containers_in_this_pod_json" | jq -r ".| select(.name == \"$container_name\") |.ready")
    container_image=$(echo "$containers_in_this_pod_json" | jq -r ".| select(.name == \"$container_name\") |.image")
    container_imageID=$(echo "$containers_in_this_pod_json" | jq -r ".| select(.name == \"$container_name\") |.imageID")
    container_image_short=${container_image##*/}
    # some container image names are just sha256 hashes. If it is, the imageID is more useful
    if [[ $container_image_short == sha256* ]]; then
      imageID="${container_imageID##*/}"  # Remove everything before the last /
      container_image_short="${imageID%%@*}"  # Remove everything after the first @
    fi
 
    if [[ "$container_ready" == "true" ]]; then
      printf "\033[32m%-${namespace_column}s %-${pod_column}s %-${container_name_column}s %-${container_image_column}s %-${status_column}s\n${RESET}" "$ns_col" "$pod" "$container_name" "$container_image_short" "$container_ready"
    else
      terminated_reason=$(echo "$pods_json" | jq -r ".| select(.name == \"$pod\") |.containers[0].state.terminated.reason")
      if [[ "$terminated_reason" == "Completed" ]]; then
        printf "\033[32m%-${namespace_column}s %-${pod_column}s %-${container_name_column}s %-${container_image_column}s %-${status_column}s\n${RESET}" "$ns_col" "$pod" "$container_name" "$container_image_short" "$terminated_reason"
      else
        if [[ "$terminated_reason" == "OOMKilled" ]]; then
          printf "${RED}%-${namespace_column}s %-${pod_column}s %-${container_name_column}s %-${container_image_column}s %-${status_column}s${RESET}\n" "$ns_col" "$pod" "$container_name" "$container_image_short" "$terminated_reason"
        else
          ((issue_counter+=1))
          printf "${RED}%-${namespace_column}s %-${pod_column}s %-${container_name_column}s %-${container_image_column}s %-${status_column}s${RESET}\n" "$ns_col" "$pod" "$container_name" "$container_image_short" "$terminated_reason ($issue_counter)"
          current_failures+=("$pod"/"$namespace")
        fi
      fi
    fi
  done
done
if [ "$hide_pod_errors" = false ]; then print_pod_failures; fi
if [ "$hide_replicaset_errors" = false ]; then print_replicaset_failures; fi
# /end-kgc
}

function print_pod_failures() {
  # Print any pods with failing containers
  if [[ ${#current_failures[@]} -gt 0 ]]; then
    printf "\nPods with failing containers:\n"
    # index is the number in () next to the failing pod
    index=1
    for failure_event in "${current_failures[@]}";  do
      IFS='/' read -r pod namespace <<< "$failure_event"
      # echo "Pod: $pod"
      # echo "Namespace: $namespace"
      print_failure_events "$pod" "$namespace" "pod"
      index=$((index+1))
    done
  fi
}

function print_replicaset_failures() {
  if [[ $namespace_arg == "all" ]]; then
    replicasets_json=$(kubectl get replicaset -A -o json)
  else
    replicasets_json=$(kubectl get replicaset -n "$namespace" -o json)
  fi
  replicasets_with_unavailable_replicas=($(jq -r '.items[] | select(.status.replicas <.spec.replicas) |.metadata.name' <<< "$replicasets_json"))
  # Check if the array has at least one element
  if [ ${#replicasets_with_unavailable_replicas[@]} -gt 0 ]; then
      printf "\nUnavailable ReplicaSets:\n"
  fi

  for replicaset_name in "${replicasets_with_unavailable_replicas[@]}";  do
      replicaset_namespace=$(echo "$replicasets_json" | jq -r ".items[]|select(.metadata.name == \"$replicaset_name\") |.metadata.namespace")
      replicaset_reason=$(echo "$replicasets_json" | jq -r ".items[]|select(.metadata.name == \"$replicaset_name\") |.status.conditions[] | select(.type == \"ReplicaFailure\") |.reason")
      replicaset_message=$(echo "$replicasets_json" | jq -r ".items[]|select(.metadata.name == \"$replicaset_name\") |.status.conditions[] | select(.type == \"ReplicaFailure\") |.message")
      print_failure_events "$replicaset_name" "$replicaset_namespace" "replica_set" "$replicaset_reason" "$replicaset_message"
  done
}

function print_failure_events() {
  current_object=$1
  current_namespace=$2
  current_type=$3
  # echo "current_object=$current_object"
  # echo "current_type=$current_type"
  # echo "current_namespace=$current_namespace"
  
  failure_reason=$(kubectl get events -n "$current_namespace" --sort-by=lastTimestamp --field-selector type!=Normal,involvedObject.name="$current_object" -ojson | jq -r '.items[0].message' 2> /dev/null)
  # print simple error messages for common issues
  if [[ $failure_reason = *"free ports"* ]]; then
    printf "${RED}(%s) ${RESET}${YELLOW}%s${RESET}${WHITE}/${RESET}${RED}%s${RESET}: ${CYAN}%s${RESET}\n" "$index" "$current_namespace" "$current_object" "hostNetwork port is in use"
  # If there are no recent events, consider restarting the pod, also kubectl descripe pod
  elif [[ $failure_reason = "null" ]]; then
    printf "${RED}(%s) ${RESET}${YELLOW}%s${RESET}${WHITE}/${RESET}${RED}%s${RESET}: ${CYAN}%s${RESET}\n" "$index" "$current_namespace" "$current_object" "No recent events"
  elif [[ $current_type == "replica_set" ]]; then
    printf "${RESET}${YELLOW}%s${RESET}${WHITE}/${RESET}${RED}%s${RESET}:\n${CYAN}%s${RESET}\n" "$current_namespace" "$current_object" "$failure_reason"
  else
    printf "${RED}(%s) ${RESET}${YELLOW}%s${RESET}${WHITE}/${RESET}${RED}%s${RESET}\n${CYAN}%s${RESET}\n" "$index" "$current_namespace" "$current_object:" "$failure_reason"
  fi
}

function print_table_header() {
  status_column=10
  if [[ $namespace_arg == "all" ]]; then
    printf "%-${namespace_column}s %-${pod_column}s %-${container_name_column}s %-${container_image_column}s %-${status_column}s\n" "namespace" "Pod" "Container Name" "Image" "Ready"
  else
    printf "\033[0;37m%s${RESET}: ${YELLOW}%s${RESET}\n" "NAMESPACE" "$namespace"
    printf " %-${pod_column}s %-${container_name_column}s %-${container_image_column}s %-${status_column}s\n" "Pod" "Container Name" "Image" "Ready"
  fi
}