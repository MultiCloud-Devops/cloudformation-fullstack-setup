
## **Example Usage**
#### Create stack
```bash
./deploy.sh create network
```

#### Preview plan (Terraform-like)
```bash
./deploy.sh plan app
```

#### Create Change Set
```bash
./deploy.sh changeset database
```

#### Update with confirmation
```bash
./deploy.sh update app
```

#### Update without asking (CI/CD safe)
```bash
./deploy.sh update app --yes
```

#### Delete stack with confirmation
```bash
./deploy.sh delete network
```
