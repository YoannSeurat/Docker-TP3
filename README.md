# Docker TP3 - Ansible

[Lien vers TP1](https://github.com/YoannSeurat/Docker-TP1)
[Lien vers TP2](https://github.com/YoannSeurat/Docker-TP2)

Ce projet automatise le provisionnement d'un serveur et le déploiement d'une stack applicative conteneurisée (PostgreSQL, API Spring Boot, reverse proxy Apache HTTPD) via Ansible et GitHub Actions.

## Architecture

Tous les conteneurs communiquent sur un réseau Docker dédié (`myapp-network`). Seul le reverse proxy est exposé sur l'hôte.

- **Proxy (`httpd:2.4`)** : écoute sur le port `80` de l'hôte et redirige le trafic (`/` et `/api/`) vers le backend.
- **Application (`yoannseurat/backend:latest`)** : API Spring Boot sur le port interne `8080`, connectée à PostgreSQL via variables d'environnement.
- **Base de données (`postgres:16`)** : instance PostgreSQL sur le port interne `5432` avec persistance des données via le volume `myapp-postgres-data`.

## Structure du projet

```text
.
├── .github/workflows/
│   └── deploy.yml                  # Pipeline CI/CD (validation et déploiement SSH)
└── ansible/
    ├── inventories/
    │   └── setup.yml               # Inventaire Ansible (groupe prod / hôte server)
    ├── playbook.yml                # Playbook principal
    ├── requirements.yml            # Dépendances Ansible Galaxy (community.docker)
    └── roles/
        ├── docker/                 # Installation de Docker Engine et du SDK Python (/opt/docker_venv)
        ├── network/                # Création du réseau Docker partagé
        ├── database/               # Déploiement du conteneur PostgreSQL
        ├── app/                    # Déploiement du conteneur backend Spring Boot
        └── proxy/                  # Configuration et déploiement du reverse proxy Apache
```

## Prérequis

- Ansible 2.15+
- Collection Ansible `community.docker` :
  ```bash
  ansible-galaxy collection install -r ansible/requirements.yml
  ```
- Un serveur Debian accessible en SSH avec un utilisateur disposant des droits `sudo`.

## Variables de configuration

### Variables de connexion et secrets

| Variable | Description | Valeur par défaut |
| --- | --- | --- |
| `SERVER_HOST` | Adresse IP ou nom DNS du serveur cible | Requis |
| `ANSIBLE_USER` | Utilisateur SSH | `admin` |
| `ANSIBLE_CONNECTION` | Mode de connexion (`ssh` ou `local`) | `ssh` |
| `ANSIBLE_PRIVATE_KEY_FILE` | Chemin vers la clé privée SSH | Clé par défaut / agent SSH |
| `POSTGRES_PASSWORD` | Mot de passe de la base PostgreSQL | Requis |

### Variables des rôles (surchargeables)

| Rôle | Variable | Valeur par défaut |
| --- | --- | --- |
| `docker` | `docker_python_venv` | `/opt/docker_venv` |
| `network` | `docker_network_name` | `myapp-network` |
| `database` | `database_container_name` | `mydb` |
| `database` | `database_image` | `postgres:16` |
| `database` | `database_volume_name` | `myapp-postgres-data` |
| `database` | `database_user` | `admin` |
| `database` | `database_name` | `myapp` |
| `app` | `app_container_name` | `myapp` |
| `app` | `app_image` | `yoannseurat/backend:latest` |
| `app` | `app_port` | `8080` |
| `proxy` | `proxy_container_name` | `httpd` |
| `proxy` | `proxy_image` | `httpd:2.4` |
| `proxy` | `proxy_http_port` | `80` |

## Utilisation manuelle

### Vérification de la syntaxe

```bash
ansible-playbook --syntax-check -i ansible/inventories/setup.yml ansible/playbook.yml
```

### Déploiement à distance via SSH

```bash
export SERVER_HOST="203.0.113.10"
export ANSIBLE_USER="admin"
export ANSIBLE_PRIVATE_KEY_FILE="$HOME/.ssh/id_rsa"
export POSTGRES_PASSWORD="votre-mot-de-passe"

ansible-playbook -i ansible/inventories/setup.yml ansible/playbook.yml \
  -e "ansible_host=$SERVER_HOST" \
  -e "ansible_user=$ANSIBLE_USER" \
  -e "ansible_connection=ssh" \
  -e "database_password=$POSTGRES_PASSWORD" \
  --private-key "$ANSIBLE_PRIVATE_KEY_FILE"
```

### Exécution locale sur le serveur cible

```bash
export POSTGRES_PASSWORD="votre-mot-de-passe"

ansible-playbook -i ansible/inventories/setup.yml ansible/playbook.yml \
  -e "ansible_host=localhost" \
  -e "ansible_connection=local" \
  -e "database_password=$POSTGRES_PASSWORD"
```

Une fois le déploiement terminé, l'API est accessible sur `http://<SERVER_HOST>/` et `http://<SERVER_HOST>/api/`.

## Déploiement continu (GitHub Actions)

Le workflow `.github/workflows/deploy.yml` est déclenché manuellement (`workflow_dispatch`) ou lors d'un push modifiant `backend/**`, `ansible/**` ou le fichier de workflow.

Il exécute deux jobs :
1. **`install-ansible`** : installe Ansible et la collection `community.docker`, puis valide la syntaxe du playbook.
2. **`deploy`** : se connecte en SSH au serveur cible, clone ou met à jour le dépôt (`git pull --ff-only`), installe les dépendances Ansible et exécute le playbook localement sur le serveur.

### Secrets GitHub Actions requis

- `SERVER_HOST` : IP ou DNS du serveur cible
- `SSH_PRIVATE_KEY` : Clé privée SSH pour la connexion au serveur
- `POSTGRES_PASSWORD` : Mot de passe PostgreSQL
- `SERVER_USER` *(optionnel)* : Utilisateur SSH (`admin` par défaut)
- `DEPLOY_PATH` *(optionnel)* : Répertoire de déploiement sur le serveur (`/home/admin/docker/TP3` par défaut)

