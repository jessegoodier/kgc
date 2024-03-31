# kgc

>The python version is a work in progress. Use the shell version for now

This is a Kubernetes script to quickly find all containers and their status

The name kgc is because it is like the alias `kgp` for kubectl get pods
kgc is to `kubectl get containers`

It also prints related errors to help identify the cause of failing containers

## Usage

Install the dependencies:

```sh
pip install -r requirements.txt
```

Run the script:
kgc [your-namespace]
