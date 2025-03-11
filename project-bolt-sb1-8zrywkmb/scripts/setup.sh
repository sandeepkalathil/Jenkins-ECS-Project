#!/bin/bash

# Create project structure
mkdir -p src k8s ecs terraform

# Initialize Git repository
git init

# Create necessary files
touch README.md
touch .gitignore
touch Dockerfile
touch Jenkinsfile
touch docker-compose.yml

# Create Kubernetes directory structure
mkdir -p k8s/base
mkdir -p k8s/overlays/dev
mkdir -p k8s/overlays/prod

# Create ECS directory structure
mkdir -p ecs/task-definitions
mkdir -p ecs/services

# Create Terraform directory structure
mkdir -p terraform/modules
mkdir -p terraform/environments/dev
mkdir -p terraform/environments/prod

# Create source code directory structure
mkdir -p src/components
mkdir -p src/hooks
mkdir -p src/utils
mkdir -p src/types
mkdir -p src/tests

# Initialize npm project
npm init -y

# Add basic .gitignore
cat << EOF > .gitignore
node_modules/
dist/
build/
.env
.env.local
.env.*.local
*.log
.DS_Store
coverage/
.terraform/
*.tfstate
*.tfstate.*
EOF

echo "Project structure created successfully!"