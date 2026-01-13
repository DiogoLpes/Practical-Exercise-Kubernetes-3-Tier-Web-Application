📚 3-Tier Library Management System on Kubernetes
A cloud-native 3-tier web application consisting of a Django-based logic layer and a PostgreSQL persistence layer, fully orchestrated using Kubernetes.

🏗️ Architecture
The application follows a standard 3-Tier Architecture:

Presentation/Application Tier: Django web server running in a Deployment with 2 replicas.

Logic Tier: Managed within the Django pods using Poetry for dependency management.

Data Tier: PostgreSQL 17 database managed via a StatefulSet and a Headless Service for stable network identity.

🚀 Installation and Setup
1. Prerequisites
A running Kubernetes cluster (e.g., Minikube).

kubectl CLI installed and configured.


1. Deploy the Project
Run these commands in order. This sets up the environment and the servers.

Bash:

make setup

