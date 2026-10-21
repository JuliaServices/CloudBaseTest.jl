# CloudBaseTest.jl

Test helpers for [CloudBase.jl](https://github.com/JuliaServices/CloudBase.jl) and the
packages built on it:

* `Minio.with` and `Azurite.with` start a local MinIO or Azurite server, create a
  bucket or container, and pass the credentials and store to your test code.
* `ECS`, `EC2`, `AzureVM`, `GCPTokenServer`, `GCPMetadata`, `GCPSTS`, and
  `GCPImpersonation` serve mock cloud credential endpoints.

These helpers were previously `CloudBase.CloudTest`. They bundle MinIO, Azurite,
and Node.js 16 binaries, so add CloudBaseTest to your test dependencies only, never to
the dependencies your package or application uses at runtime:

```toml
[extras]
CloudBaseTest = "40fa5d0e-b06b-47c4-9127-3a501b82bf72"

[targets]
test = ["CloudBaseTest", "Test"]
```

```julia
using CloudBase, CloudBaseTest

Minio.with() do conf
    credentials, bucket = conf
    CloudBase.AWS.put("$(bucket.baseurl)hello.txt", [], "hello"; service="s3", credentials)
end
```

To migrate from CloudBase 1.x, replace `CloudBase.CloudTest` with `CloudBaseTest`.
