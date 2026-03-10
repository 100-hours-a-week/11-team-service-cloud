# modules/s3

S3 버킷 모듈.

포함:
- S3 bucket
- (옵션) versioning
- (옵션) SSE (AES256 / KMS)
- (기본) public access block
- (옵션) Bucket policy: 특정 VPC Endpoint(aws:sourceVpce) 통해서만 접근 제한

## 사용 예시

```hcl
module "scuad_dev_config" {
  source = "../../modules/s3"

  # S3 bucket name은 underscore(_) 불가라서 보통 하이픈(-)으로 잡아.
  bucket_name       = "scuad-dev-config-${local.environment}-<unique-suffix>"
  enable_versioning = true
  sse_algorithm     = "AES256" # 또는 "aws:kms"

  # VPC Endpoint로만 제한하고 싶으면:
  restrict_to_vpce = true
  vpce_id          = aws_vpc_endpoint.s3.id
}
```

주의:
- `bucket_name`은 전 세계에서 유일해야 함
- S3 bucket name 규칙상 `_`는 사용할 수 없음
