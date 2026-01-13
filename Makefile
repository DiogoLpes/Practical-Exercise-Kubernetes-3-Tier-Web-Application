.PHONY:help 

help:       
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

## ----------------------------------------------------------------------------
## Setup command
## ----------------------------------------------------------------------------

run: ## Setup and run the entire application stack 	
	@echo "Setting up and running the entire application stack..."

## 1- Creating migrations, applying them
## 2- Creating admin user 
## 3- Loading books data 
## 4- And starting services
	
	docker compose run --rm app poetry run python django-app/manage.py makemigrations
	docker compose run --rm app poetry run python django-app/manage.py migrate
	docker compose run --rm app poetry run python django-app/manage.py shell -c "from library.models import Users; Users.objects.create(name='admin', email='admin@example.com', password='Admin123', role='admin'), Users.objects.create(name='Bruno', password='Bruno123', email='bruno@gmail.com', role='user'), print('Admin and Bruno created successfully.')";
	docker compose run --rm app poetry run python django-app/manage.py load_books_data ./books.json
	docker compose up --build --force-recreate  

## ----------------------------------------------------------------------------
## Docker compose commands  
## ---------------------------------------------------------------------------- 

up: ## Start all services defined in compose.yml without rebuilding
	@echo "Starting all services defined in compose.yml..."
	docker compose up 
	
up-build: ## 2 - Start all services defined in compose.yml with rebuilding and creating superuser
	@echo "Starting all services defined in compose.yml with rebuilding..."
	docker compose up --build --force-recreate

down: ## Stop and remove all containers
	@echo "Stopping and removing all containers..."
	docker compose down
	
clean: ## Stop and remove all containers and volumes
	@echo "Stopping and removing all containers and volumes..."
	docker compose down --volumes
	docker system prune -a
	
compose.migrations: ## Create new database migrations on service running...
	docker compose run --rm app poetry run python django-app/manage.py makemigrations

compose.migrate: compose.migrations ## Apply database migrations on service running...
	@echo "🛠️  Applying migrations inside Docker container..."
	docker compose run --rm app poetry run python django-app/manage.py migrate

compose.createsuperuser:  ## Create a superuser on service running...
	@echo "👤 Creating superuser inside Docker container..."
	docker compose run --rm app poetry run python django-app/manage.py createsuperuser

createadmin:
	docker compose run --rm app poetry run python django-app/manage.py shell -c "from library.models import Users; \
	Users.objects.create(name='admin', email='admin@example.com', password='Admin123', role='admin'); \
	print('Admin user created successfully.')"

compose.load-books: ## Load books into the running Docker Django container
	@echo "📚 Loading books inside Docker container..."
	docker compose run --rm app poetry run python django-app/manage.py load_books_data ./books.json

test: ## Run tests inside Docker container
	@echo "Running tests inside Docker container..."
	docker compose run --rm -w /app/django-app app poetry run pytest --verbose
	
#--------------------------------------------------------------------

setup:
	@echo "1. Starting Minikube and Addons..."
	minikube start
	minikube addons enable ingress

	@echo "2. Applying Secrets..."
	# Creating the secret with the name and keys the database expects
	kubectl create secret generic db-secret \
  		--from-literal=POSTGRES_DB=library_db \
  		--from-literal=POSTGRES_USER=admin \
  		--from-literal=postgres-password=yourpassword \
  		--from-literal=POSTGRES_HOST=postgres-service \
  		--from-literal=POSTGRES_PORT=5432 \
  		--dry-run=client -o yaml | kubectl apply -f -
	
	# Creating the secret for Django application
	kubectl create secret generic app-env \
		--from-literal=SECRET_KEY=your-django-key \
		--dry-run=client -o yaml | kubectl apply -f -

	@echo "3. Building Image inside Minikube..."
	# Pointing docker to minikube's internal docker daemon
	@eval $$(minikube docker-env) && docker build -t cloud:latest -f ./ops/Dockerfile .

	@echo "4. Deploying Database Stack..."
	kubectl apply -f k8s/database/postgres-service.yaml
	kubectl apply -f k8s/database/postgres-statefulset.yaml
	
	@echo "5. Waiting for Database to be ready..."
	sleep 10
	kubectl wait --for=condition=ready pod -l app=postgres --timeout=60s

	@echo "6. Deploying Backend Application..."
	kubectl apply -f k8s/backend/deployment.yaml
	kubectl apply -f k8s/backend/service.yaml
	kubectl apply -f k8s/backend/django-ingress.yaml

deploy:
	kubectl port-forward service/ingress-nginx-controller 8080:80 -n ingress-nginx
	

