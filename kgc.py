import subprocess
import json
import sys
from prettytable import PrettyTable
from termcolor import colored

def run_command(command):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    output, error = process.communicate()
    return output.decode('utf-8'), error.decode('utf-8')

def get_failure_events(namespace, name):
    command = f"kubectl get events -n {namespace} --sort-by=lastTimestamp --field-selector involvedObject.name={name}"
    output, error = run_command(command)
    return output

def print_pods_table(pods):
    table = PrettyTable()
    table.align = "l"  # Left align all columns
    table.border = False  # Don't draw a border around the table
    table.field_names = ["Pod Name", "Container Name", "Status"]
    for pod,container,status in pods:
        if status == "Ready" or status == "Completed":
            status = colored(status, 'green')
        elif status == "Pending":
            status = colored(status, 'yellow')
        else:
            status = colored(status,'red')
        table.add_row([pod,container,status])
    print(table)

def kgc_all():
    print("Getting containers in all namespaces")
    output, error = run_command("kubectl get ns -o jsonpath='{.items[*].metadata.name}'")
    namespaces = output.split()
    for ns in namespaces:
        kgc(ns)

def kgc(namespace):
    if namespace == "all":
        kgc_all()
        return

    if not namespace:
        output, error = run_command("kubectl config view --minify --output 'jsonpath={..namespace}'")
        namespace = output.strip()

    print(f"NAMESPACE: {namespace}")

    # Pull the json payload one time for performance reasons
    output, error = run_command(f"kubectl get pods -n {namespace} -o json")
    pods_json = json.loads(output)

    # check if there are any pods in this namespace
    num_pods = len([pod['metadata']['name'] for pod in pods_json['items']])
    if num_pods == 0:
        print(f"No pods found in {namespace} namespace")
        return

    current_failures = []
    kgc_table_row = []
    # for pod in pod_list:
    for pod in pods_json['items']:
        # check if there are any containers in this pod
        if not 'containerStatuses' in pod['status']:
            first_reason = pod['status']['conditions'][0]['reason']
            # add the row to the table
            kgc_table_row += [(pod['metadata']['name'], "-", first_reason)]
            continue
        for container in pod['status']['containerStatuses']:
            # print(f"Container: {container['name']}, Ready: {container['ready']}")
            if container['ready'] == True:
                kgc_table_row += [(pod['metadata']['name'], container['name'], "Ready")]
            elif 'terminated' in container['state'] and container['state']['terminated']['reason'] == 'Completed':
                kgc_table_row += [(pod['metadata']['name'], container['name'], 'Completed')]
            elif pod['status']['phase'] == 'Pending':
                kgc_table_row += [(pod['metadata']['name'], container['name'], 'Pending')]
            elif 'terminated' in container['state'] and container['state']['terminated']['reason'] == 'OOMKilled':
                kgc_table_row += [(pod['metadata']['name'], container['name'], 'OOMKilled')]
            else:
                current_failures.append((pod['metadata']['name'], container['name'], container['ready']))
                kgc_table_row += [(pod['metadata']['name'], container['name'], container['ready'])]
    print_pods_table(kgc_table_row)

    # check events for pods with failing containers
    if current_failures:
        print("\nPods with failing containers:")
        for pod in current_failures:
            print(f"{pod}:")
            print(get_failure_events(namespace, pod))

    output, error = run_command(f"kubectl get replicaset -n {namespace} -o json")
    replica_sets = json.loads(output)
    replica_sets_with_unavailable_replicas = [rs['metadata']['name'] for rs in replica_sets['items'] if rs['status']['replicas'] < rs['spec']['replicas']]

    if replica_sets_with_unavailable_replicas:
        print("\nUnavailable ReplicaSets:")
        for replica_set in replica_sets_with_unavailable_replicas:
            print(f"{replica_set}:")
            print(get_failure_events(namespace, replica_set))

# If an argument is passed, use it as the namespace
if len(sys.argv) > 1:
    namespace = sys.argv[1]
else:
    command = "kubectl config view --minify --output 'jsonpath={..namespace}'"
    namespace, error = run_command(command)

def main():
    kgc(namespace)

if __name__ == "__main__":
    main()