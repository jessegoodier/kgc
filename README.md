# kgc: kubectl get containers

The name `kgc` is because it is like the alias `kgp` for `kubectl get pods`

`kgc` is to `k get containers` (if you don't alias k to kubectl, you should)

By default, it also prints related errors to help fix issues.

![kgc-screenshot](kgc.png)

## TODO

1. krew plugin
2. Python pip3 installation (WIP [README-python.md](README-python.md))
3. Inform user how to fix more issues:
    1. PV in zone with no nodes

## Requirements

1. jq version 1.6 does not work. jq-1.7.1 does work
2. bash and zsh have been tested and should both work. May need modern bash versions.

Please file an issue with the details if you find anything. Also happy to accept pull requests

## Usage


```sh
alias kgc=~/kgc.sh
```

Then run it:

`kgc [namespace]`

`kgc all` will run it against all namespaces.

Help output:

```sh
Usage: kgc.sh [namespace] OR [OPTION]...
Examples:
kgc -n kube-system - will get all pods in the kube-system namespace
kgc with no arguments will get all containers in the current context's namespace
kgc <namespace> - will get all pods in the specified namespace
Available options:
  -a or -A       Get containers in all namespaces
  -n namespace   Specific namespace
  -p             Hide pod error list. This can be added to the alias to make it the default behavior
  -r             Hide replicaset error list. This can be added to the alias to make it the default behavior
  -h or --help   Display this help and exit
```

## Installation

>You should always read and understand a script before running it. This is a good practice to avoid running malicious code.

Copy and paste from here: [kgc shell script](kgc.sh)

Or simply:

```sh
wget -O ~/kgc.sh https://raw.githubusercontent.com/jessegoodier/kgc/main/kgc.sh
echo "alias kgc=~/kgc.sh" >> ~/.zshrc
echo "alias kgc=~/kgc.sh" >> ~/.bashrc
```

## More resources

Dockerfile with this script and general zsh profile config that I use:
[jesse-zsh-profile](https://github.com/jessegoodier/jesse-zsh-profile)
