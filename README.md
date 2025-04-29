# Docker-based Laravel Environment for Production/Staging

A streamlined Docker setup for Laravel applications with Nginx, PHP-FPM, and additional services. This setup includes automated scripts for easy deployment and management.

## 🌟 Features

- **Containerized Services**
  - PHP-FPM (8.3+ default)
  - Nginx
  - Queue Worker (optional)
  - Cron Jobs (optional)

- **Automation Scripts**
  - Docker installation
  - Environment setup
  - Nginx configuration
  - SSL certificate management
  - Swap memory management

## 🚀 Quick Start

### Prerequisites
- Ubuntu/Debian-based system
- Git
- Basic command line knowledge

### Installation

1. **Clone your Laravel project**
   ```bash
   git clone <your-project-url>
   cd <project-directory>
   ```

2. **Set up environment file**
   ```bash
   cp .env.example .env
   ```

   Configure these essential variables:
   ```env
   COMPOSE_PROJECT_NAME=dev_abc
   APP_NAME=abc
   ENV=dev

   CONTAINER_PORT=8000
   HOST_URL=abc.com
   HOST_PORT=80

   ENABLE_CRON=false
   ENABLE_JOB=false

   PHP_VERSION=8.3
   PHP_MEMORY_LIMIT=512M
   PHP_UPLOAD_MAX_FILESIZE=30M
   PHP_POST_MAX_SIZE=30M
   PHP_MAX_EXECUTION_TIME=60
   
   ENABLE_MONGODB_EXTENSION=false
   ENABLE_MONGODB_EXTENSION_VERSION=1.20.0
   ```

3. **Run the magic script**
   ```bash
   cd docker
   chmod +x magic.sh
   ./magic.sh
   ```

## 🎯 Available Commands

The `magic.sh` script provides these options:

```bash
1. Install Docker and Docker Compose
2. Docker Compose Up
3. Docker Compose Down
4. Docker PS
5. Goto Bash
6. Delete All Unused Docker Images
7. Set Swap Memory
8. Create NGINX Server Block
9. Delete NGINX Server Block
10. Install Lets Encrypt SSL Certificate
```

## 🛠 Development Workflow

### Starting the Environment

1. **Start all services**
   ```bash
   ./magic.sh
   # Select option 2: "Docker Compose Up"
   ```

2. **Access your application**
   - Local development: `http://localhost:8000`
   - With domain: `http://your-domain.com`


### Container Management

Access container shell:
```bash
./magic.sh
# Select option 5: "Goto Bash"
```

View running containers:
```bash
./magic.sh
# Select option 4: "Docker PS"
```

## 📁 Project Structure

```
docker/
├── Dockerfile              # PHP-FPM container configuration
├── docker-compose.yml      # Main docker-compose configuration
├── docker-compose.job.yml  # Queue worker configuration
├── docker-compose.cron.yml # Cron jobs configuration
├── magic.sh               # Main automation script
├── bash/
│   ├── utility.sh         # Common utility functions
│   ├── docker.sh          # Docker-related functions
│   ├── nginx.sh           # Nginx configuration functions
│   └── certbot.sh         # SSL certificate functions
├── nginx/
│   └── reverse_proxy.conf # Nginx reverse proxy configuration
└── php/
    └── local.ini          # PHP configuration
```

## 🔧 Configuration

### PHP Extensions
The following extensions are pre-installed:
- pdo_mysql
- mbstring
- exif
- pcntl
- bcmath
- gd
- zip
- intl
- calendar
- redis

### Nginx Configuration
The reverse proxy includes:
- GZIP compression
- WebSocket support
- Security headers
- File access restrictions
- Error pages

## 🔒 Security Features

- Automatic SSL certificate management
- HTTP/2 support
- Security headers
- Protected file access
- GZIP compression
- Rate limiting

## 🐛 Troubleshooting

1. **Permission Issues**
   ```bash
   # Fix storage permissions
   chmod -R 775 storage bootstrap/cache
   chown -R www-data:www-data storage bootstrap/cache
   ```

2. **Container Access Denied**
   ```bash
   # Add your user to docker group
   sudo usermod -aG docker $USER
   newgrp docker
   ```

3. **Nginx Configuration Issues**
   ```bash
   # Check Nginx configuration
   sudo nginx -t
   ```

## 📝 License

This project is open-sourced software licensed under the MIT license.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
