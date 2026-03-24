# SSM tunnel for kube-apiserver (prod)

This setup assumes:
- Control plane nodes are in private subnets
- kube-apiserver endpoint is an **internal NLB** (TCP/6443)
- You access the cluster from anywhere using **SSM port forwarding** (no SSH, no public 6443)

## 1) Prereqs
- AWS CLI configured for the right account/role
- Session Manager plugin installed
- IAM permission to StartSession on the control plane instances

## 2) Pick a control plane instance id
Terraform output (after apply):
- `control_plane_instance_ids`

Pick any one id from the list as the SSM target.

## 3) Start port forwarding
Replace placeholders:
- `<cp_instance_id>`: one of control plane instance ids
- `<internal_nlb_dns>`: Terraform output `control_plane_internal_endpoint`

```bash
aws ssm start-session \
  --target <cp_instance_id> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "host=<internal_nlb_dns>,portNumber=6443,localPortNumber=6443"
```

Keep this running.

## 4) kubeconfig
Set your kubeconfig cluster server to:
- `https://127.0.0.1:6443`

Then:
```bash
kubectl get nodes
```
