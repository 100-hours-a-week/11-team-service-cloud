# kubeadm join materials in SSM Parameter Store (prod)

Workers auto-join by reading two parameters at boot:
- Join token
- Discovery token CA cert hash

These parameter names are configured in `terraform.tfvars`:
- `kubeadm_join_token_ssm_param_name`
- `kubeadm_ca_hash_ssm_param_name`

## Create/update the parameters (run from your workstation)

### 1) Generate values on a control plane node
On the control plane (after kubeadm init):

- Join token (long TTL example):
```bash
sudo kubeadm token create --ttl 8760h
```

- CA cert hash:
```bash
sudo openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
  | openssl rsa -pubin -outform der 2>/dev/null \
  | openssl dgst -sha256 -hex \
  | awk '{print "sha256:"$2}'
```

### 2) Put them into SSM Parameter Store
Replace:
- `<JOIN_TOKEN>`
- `<CA_HASH>`

```bash
aws ssm put-parameter \
  --name "/scuad/v3/prod/kubeadm/join_token" \
  --type "SecureString" \
  --value "<JOIN_TOKEN>" \
  --overwrite

aws ssm put-parameter \
  --name "/scuad/v3/prod/kubeadm/ca_cert_hash" \
  --type "SecureString" \
  --value "<CA_HASH>" \
  --overwrite
```

## Notes
- The worker IAM role allows `ssm:GetParameter` only for these two names.
- If you rotate the token later, just `put-parameter --overwrite` again.
