# memex-suite

Memex Suite is a Python 3.12/FastAPI microservice suite deployed to AWS Lambda
with AWS SAM.

## Current focus

The active environment path is AWS deployment. LocalStack/docker-compose
scaffolding exists in the repository, but it is deferred and should not block the
AWS build-out.

## Build and test

```bash
make install
make lint
make test
make build
```

`make build` uses the root SAM template at `infrastructure/template.yaml`,
runs custom build targets from the root `Makefile`, and writes deployable
artifacts under `.aws-sam/build/`.

## AWS deployment

Production deploys are handled by `.github/workflows/deploy.yml` on pushes to
`main`.

Required GitHub configuration:

- Secret `AWS_DEPLOY_ROLE_ARN`: the `platform-bootstrap` output
  `service_deploy_role_arns["memex-suite"]`
- Variable `AWS_SAM_BUCKET`: the `platform-bootstrap` output
  `service_artifact_buckets["memex-suite"]`

Manual deploys can use:

```bash
make deploy-aws
```

That target builds with SAM, then deploys `.aws-sam/build/template.yaml`.
