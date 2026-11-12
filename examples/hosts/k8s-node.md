# k8s-worker-14.prod.example.net

## Role
Kubernetes worker node, production cluster `prod-eu1`. Runs customer-facing
workloads. The node is cattle: it can be drained and replaced at any time,
but only through the process below.

## Owner
Team platform. On-call: #platform-oncall.

## Change process
The node is built from an image. Nothing on it is edited by hand. A local
change is lost at the next rebuild, and it makes this node differ from the
other 40 nodes, which is how the last three outages started.

- To change the node: change the image repository `infra/node-image`.
- To fix a sick node: cordon, drain, replace. Do not repair in place.

## Where things are
- kubelet logs: `journalctl -u kubelet`
- containerd logs: `journalctl -u containerd`
- Pod logs: use `kubectl logs` from the control side, not files in
  /var/log/pods.

## Safe operations
- Read-only commands: `crictl ps`, `crictl logs`, `journalctl`, `ss`,
  `df`, `dmesg`.
- `kubectl cordon` on this node.

## Do not
- Do not reboot a node that is not cordoned and drained. Its pods stop
  without eviction, so PodDisruptionBudgets do not apply.
- Do not run `crictl rm` or `crictl rmp`. The kubelet recreates the
  container, and you lose the evidence.
- Do not delete files in /var/lib/containerd to free disk space. Use the
  kubelet image garbage collection thresholds.
- Do not use `kubectl drain` with `--force` or
  `--disable-eviction`. PodDisruptionBudgets protect the payment service.

## Escalation
More than one node NotReady at the same time is a cluster problem, not a
node problem. Stop and page the on-call.

Last reviewed: 2026-11-12
