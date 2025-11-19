A beginner-friendly CI/CD pipeline using Ansible Vault for secrets management.

## Technologies
- Git - Version control
- Ansible + Ansible Vault - Automation & secrets
- Docker - Containerization
- Jenkins - CI/CD orchestration
- Flask - Python web app
# Testing ngrok webhook
#New Test ngrok webhook

# CI/CD Pipeline with Ansible Vault

A two-VM deployment pipeline using Jenkins, Docker, and Ansible. This project demonstrates automated deployments with encrypted secrets management.

---

## What This Does

This pipeline automates the entire deployment process for a Flask web application. Push your code to GitHub, and it automatically builds a Docker image, encrypts your secrets, and deploys to a production server.

**The workflow:**
```
Code Push → GitHub → Jenkins builds Docker image → Ansible deploys to VM → App goes live
```

**Why two VMs?**
- VM1: Runs the actual application (Docker container with Flask)
- VM2: Handles the build process (Jenkins + Ansible orchestration)

This separation keeps your build tools away from production and makes everything more secure.

---

## Tech Stack

- **Jenkins** - Automates the pipeline
- **Docker** - Packages the application
- **Ansible** - Handles deployment
- **Ansible Vault** - Encrypts secrets (passwords, API keys, etc.)
- **Flask** - Simple Python web framework
- **Debian 12** - OS on both VMs

---

## Project Structure

```
├── app/                    # Flask application
│   ├── app.py
│   ├── requirements.txt
│   └── templates/
├── ansible/
│   ├── inventory           # Server details
│   ├── group_vars/all/
│   │   ├── vars.yml        # Public config
│   │   └── vault.yml       # Encrypted secrets
│   └── playbooks/
│       └── deploy.yml      # Deployment steps
├── docker/
│   └── Dockerfile
├── jenkins/
│   └── Jenkinsfile         # Pipeline definition
└── ansible.cfg
```

**About secrets:** The `vault.yml` file is encrypted with Ansible Vault. It's safe to commit to Git because it's just encrypted gibberish without the password. The actual password (`.vault_pass`) stays local and never goes to Git.

---

## Getting Started

### What You Need

- Two VMs with Debian 12 (2 CPU, 4GB RAM each)
- SSH access to both
- Git and GitHub account

### Setup Overview

1. **VM1 (App Server)**
   - Install Docker
   - Create a deploy user
   - Set up SSH access from VM2

2. **VM2 (Jenkins Server)**
   - Install Jenkins, Docker, and Ansible
   - Clone this repository
   - Configure the pipeline

3. **Connect Everything**
   - Set up SSH keys between VMs
   - Create encrypted vault with your secrets
   - Configure Jenkins credentials
   - Run your first build

The full setup process is documented in [INSTALLATION_GUIDE.md](docs/INSTALLATION_GUIDE.md).

---

## How to Deploy

### Automatic (the whole point of this)
```bash
git add .
git commit -m "Update app"
git push
```
Jenkins picks it up and deploys automatically.

### Manual via Jenkins
Go to `http://your-jenkins-vm:8080`, find your pipeline, click "Build Now".

### Manual via Ansible
```bash
cd /opt/cicd-project
ansible-playbook -i ansible/inventory ansible/playbooks/deploy.yml \
    --vault-password-file=.vault_pass
```

After deployment, access your app at `http://your-app-vm:5000`.

---

## Pipeline Stages

**1. Checkout**
Pulls latest code from GitHub.

**2. Build**
Creates a Docker image with your application and dependencies.

**3. Save**
Exports the image to a tar file.

**4. Deploy**
- Transfers image to VM1 via SCP
- Uses Ansible to load and run the container
- Injects encrypted secrets as environment variables

**5. Cleanup**
Removes temporary files and reports status.

The whole process takes about 1-2 minutes.

---

## Managing Secrets

All secrets go in `ansible/group_vars/all/vault.yml`, encrypted with Ansible Vault.

**View secrets:**
```bash
ansible-vault view ansible/group_vars/all/vault.yml --vault-password-file=.vault_pass
```

**Edit secrets:**
```bash
ansible-vault edit ansible/group_vars/all/vault.yml --vault-password-file=.vault_pass
```

**What gets encrypted:**
- Database passwords
- API keys
- Secret keys for your app
- Any other sensitive config

The vault file itself is committed to Git (it's encrypted), but the password file (`.vault_pass`) stays local.

---

## Troubleshooting

**Jenkins can't build Docker images**
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

**Ansible can't connect to VM1**
```bash
# Test SSH manually
ssh deploy@your-vm1-ip

# Check Ansible can reach it
ansible app_servers -m ping
```

**Container won't start on VM1**
```bash
docker logs flask-app
```

More help in [ANSIBLE_VAULT_TROUBLESHOOTING.md](docs/ANSIBLE_VAULT_TROUBLESHOOTING.md).

---

## What's Different Here

Most CI/CD tutorials skip the secrets management part or use external services. This project shows how to do it with just Ansible Vault - no HashiCorp Vault server, no AWS Secrets Manager, just one tool that's already part of Ansible.

Also, this uses a two-VM setup which is closer to how you'd actually do this in production, rather than running everything on one machine.

---

## What I Learned Building This

- How to properly encrypt secrets in a Git repository
- Setting up Jenkins pipelines from scratch
- Ansible playbook development and debugging
- Docker image building and transfer between machines
- SSH key management between systems
- Debian package management (it's different from Ubuntu!)
- A lot of troubleshooting

The [LESSONS_LEARNED.md](docs/LESSONS_LEARNED.md) document has all the issues I ran into and how I fixed them.

---

## Possible Improvements

Things that could make this better:
- Add automated tests before deployment
- Set up Nginx as a reverse proxy on VM1
- Add SSL with Let's Encrypt
- Implement blue-green deployments
- Add monitoring (Prometheus/Grafana)
- Use a proper Docker registry instead of SCP transfer

---

## Documentation

- [INSTALLATION_GUIDE.md](docs/INSTALLATION_GUIDE.md) - Complete setup instructions
- [SUCCESS_SUMMARY.md](docs/SUCCESS_SUMMARY.md) - Working configuration reference
- [LESSONS_LEARNED.md](docs/LESSONS_LEARNED.md) - Problems encountered and solutions
- [ANSIBLE_VAULT_TROUBLESHOOTING.md](docs/ANSIBLE_VAULT_TROUBLESHOOTING.md) - Vault-specific issues

---

## Notes

Built as a learning project to understand CI/CD pipelines and DevOps practices. The setup works in production but there are definitely ways to improve it (see above).

The pipeline currently takes about 90 seconds to deploy a change. Most of that is Docker image transfer - using a registry would speed this up.

---

**Status:** Working ✓

Last tested: November 2024
