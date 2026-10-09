# Ansible deployment

This directory implements the TP with five roles:

1. `docker` installs Docker Engine, enables the service, and creates the Python
   virtual environment used by `community.docker`.
2. `network` creates the shared Docker network.
3. `database` runs PostgreSQL with a persistent Docker volume.
4. `app` runs the backend and injects its database connection variables.
5. `proxy` runs Apache HTTPD and reverse-proxies requests to the backend.

## Prerequisites

- Ansible 2.15 or newer on the machine launching the playbook.
- A Debian server reachable over SSH, with a user allowed to use `sudo`.
- The `community.docker` collection:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

## Configure the target

The inventory only defines the `server` host group. Connection details must be
passed explicitly to Ansible; this avoids Ansible silently treating a missing
environment variable as `localhost`.

| Variable | Meaning | Default |
| --- | --- | --- |
| `SERVER_HOST` | DNS name or IP of the managed server | required |
| `ANSIBLE_USER` | SSH user | `admin` |
| `ANSIBLE_CONNECTION` | `ssh` for a remote server, `local` on the server itself | `ssh` |
| `ANSIBLE_PRIVATE_KEY_FILE` | SSH private key path | SSH agent/default key |
| `POSTGRES_PASSWORD` | Database password (at least 12 characters) | required |

For a remote deployment, configure the SSH private key through Ansible's
normal SSH agent or `ANSIBLE_PRIVATE_KEY_FILE`, then run:

```bash
export SERVER_HOST="203.0.113.10"
export ANSIBLE_USER="admin"
export ANSIBLE_CONNECTION="ssh"
export ANSIBLE_PRIVATE_KEY_FILE="$HOME/.ssh/id_rsa"
export POSTGRES_PASSWORD="use-a-secret-password"
ansible-playbook --syntax-check -i ansible/inventories/setup.yml ansible/playbook.yml
ansible-playbook -i ansible/inventories/setup.yml ansible/testconnection.yml \
  -e "ansible_host=$SERVER_HOST" \
  -e "ansible_user=$ANSIBLE_USER" \
  -e "ansible_connection=$ANSIBLE_CONNECTION" \
  --private-key "$ANSIBLE_PRIVATE_KEY_FILE"
ansible-playbook -i ansible/inventories/setup.yml ansible/playbook.yml \
  -e "ansible_host=$SERVER_HOST" \
  -e "ansible_user=$ANSIBLE_USER" \
  -e "ansible_connection=$ANSIBLE_CONNECTION" \
  -e "database_password=$POSTGRES_PASSWORD" \
  --private-key "$ANSIBLE_PRIVATE_KEY_FILE"
```

For a playbook run directly on the Docker server:

```bash
export ANSIBLE_CONNECTION="local"
export SERVER_HOST="localhost"
ansible-playbook -i ansible/inventories/setup.yml ansible/playbook.yml \
  -e "ansible_host=$SERVER_HOST" \
  -e "ansible_connection=$ANSIBLE_CONNECTION" \
  -e "database_password=$POSTGRES_PASSWORD"
```

The public API is then available at `http://SERVER_HOST/` and the explicit API
prefix is available at `http://SERVER_HOST/api/`. The backend is not published
directly; only Apache publishes port 80.

## Custom images and ports

Role defaults are intentionally overridable. For example:

```powershell
ansible-playbook -i ansible/inventories/setup.yml ansible/playbook.yml `
  -e app_image=your-dockerhub-user/backend:1.0 `
  -e app_port=8080 `
  -e proxy_http_port=8080
```

Do not commit passwords, private keys, or a Vault password. In a real
deployment, pass the database password from Ansible Vault or CI secrets.

## Continuous deployment

`.github/workflows/deploy.yml` deploys on backend/Ansible changes and can also
be started manually. Configure `SERVER_HOST`, `SSH_PRIVATE_KEY`,
`POSTGRES_PASSWORD`, and optionally `SERVER_USER` in GitHub Actions secrets.
The remote checkout must already exist at `~/docker/TP3`, because the workflow
updates it with `git pull --ff-only`.

The workflow does not magically detect every Docker Hub push: add a Docker Hub
webhook that calls `workflow_dispatch` (or use a scheduled workflow) if that
behavior is required.
