# n8n Local Development Setup Guide

This guide will help you set up n8n for local development with a fully self-contained Docker environment.

## 🚀 Quick Start

### Prerequisites

- **Docker Engine**: 20.10+ 
- **Docker Compose**: 2.0+
- **System Requirements**:
  - 4GB+ RAM (8GB+ recommended)
  - 20GB+ disk space
  - Multi-core CPU (4+ cores recommended)

### 1. Initial Setup

```bash
# Clone the repository (if not already done)
git clone <repository-url>
cd n8n-enterprise-ai-setup-free

# Copy environment template
cp .env.example .env

# Generate a secure encryption key
openssl rand -base64 32
```

### 2. Configure Environment

Edit the `.env` file and update these critical settings:

```bash
# Replace with your generated encryption key (32 characters)
N8N_ENCRYPTION_KEY=your-generated-32-character-key-here

# Update database passwords (recommended)
POSTGRES_PASSWORD=your-secure-db-password
REDIS_PASSWORD=your-secure-redis-password
```

### 3. Start the Environment

```bash
# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

### 4. Access n8n

- **n8n Interface**: http://localhost:5678
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379
- **Nginx Load Balancer**: http://localhost:80

## 📧 SMTP Email Configuration

### Gmail Setup (Recommended for Development)

1. **Enable 2-Factor Authentication** on your Google account
2. **Generate App Password**:
   - Go to Google Account Settings
   - Security → 2-Step Verification → App passwords
   - Generate password for "Mail"
3. **Update .env file**:
   ```bash
   N8N_SMTP_HOST=smtp.gmail.com
   N8N_SMTP_PORT=587
   N8N_SMTP_USER=your-email@gmail.com
   N8N_SMTP_PASS=your-16-character-app-password
   N8N_SMTP_SENDER=your-email@gmail.com
   N8N_SMTP_SSL=false
   N8N_SMTP_STARTTLS=true
   ```

### Other SMTP Providers

#### Microsoft Outlook/Hotmail
```bash
N8N_SMTP_HOST=smtp-mail.outlook.com
N8N_SMTP_PORT=587
N8N_SMTP_USER=your-email@outlook.com
N8N_SMTP_PASS=your-password
```

#### Yahoo Mail
```bash
N8N_SMTP_HOST=smtp.mail.yahoo.com
N8N_SMTP_PORT=587
N8N_SMTP_USER=your-email@yahoo.com
N8N_SMTP_PASS=your-app-password
```

## 🔧 Development Commands

### Service Management
```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart specific service
docker-compose restart n8n

# Scale workers
docker-compose up -d --scale n8n-worker=3

# View service logs
docker-compose logs -f n8n
docker-compose logs -f postgres
docker-compose logs -f redis
```

### Database Management
```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U n8n -d n8n

# Backup database
docker-compose exec postgres pg_dump -U n8n n8n > backup.sql

# Restore database
docker-compose exec -T postgres psql -U n8n -d n8n < backup.sql
```

### Redis Management
```bash
# Connect to Redis CLI
docker-compose exec redis redis-cli -a your-redis-password

# Monitor Redis
docker-compose exec redis redis-cli -a your-redis-password monitor

# Check queue status
docker-compose exec redis redis-cli -a your-redis-password info
```

## 🏥 Health Checks & Monitoring

### Service Health
```bash
# Check all service health
docker-compose ps

# Individual service health
docker-compose exec n8n wget -qO- http://localhost:5678/healthz
docker-compose exec postgres pg_isready -U n8n
docker-compose exec redis redis-cli -a your-redis-password ping
```

### Performance Monitoring
```bash
# View resource usage
docker stats

# Check n8n metrics (if enabled)
curl http://localhost:5678/metrics
```

## 🛠️ Troubleshooting

### Common Issues

#### n8n Won't Start
```bash
# Check logs
docker-compose logs n8n

# Common causes:
# 1. Database not ready - wait for postgres health check
# 2. Invalid encryption key - check .env file
# 3. Port conflicts - ensure 5678 is available
```

#### Database Connection Issues
```bash
# Check PostgreSQL status
docker-compose exec postgres pg_isready -U n8n

# Reset database (WARNING: destroys data)
docker-compose down -v
docker-compose up -d
```

#### Redis Connection Issues
```bash
# Test Redis connection
docker-compose exec redis redis-cli -a your-redis-password ping

# Check Redis logs
docker-compose logs redis
```

#### Worker Issues
```bash
# Check worker logs
docker-compose logs n8n-worker

# Scale workers
docker-compose up -d --scale n8n-worker=2
```

### Performance Issues

#### High Memory Usage
```bash
# Reduce worker concurrency in .env
N8N_WORKER_CONCURRENCY=5

# Limit execution data retention
EXECUTIONS_DATA_MAX_AGE=168  # 7 days
```

#### Slow Database Queries
```bash
# Enable query logging (temporary)
docker-compose exec postgres psql -U n8n -c "ALTER SYSTEM SET log_statement = 'all';"
docker-compose restart postgres
```

## 🔒 Security Considerations

### Local Development Security
- Basic auth is disabled by default for easier development
- Use secure passwords for database and Redis
- Keep encryption key secure and unique
- Don't commit real credentials to version control

### Production Preparation
- Enable HTTPS (N8N_PROTOCOL=https)
- Enable basic auth (N8N_BASIC_AUTH_ACTIVE=true)
- Use strong passwords and encryption keys
- Configure proper firewall rules
- Enable SSL for database connections

## 📊 Scaling & Performance

### Horizontal Scaling
```bash
# Scale workers based on load
docker-compose up -d --scale n8n-worker=5

# Monitor queue metrics
docker-compose exec redis redis-cli -a password info
```

### Resource Optimization
```bash
# Adjust worker concurrency
N8N_WORKER_CONCURRENCY=20

# Configure execution data pruning
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=336  # 14 days
```

## 🔄 Backup & Restore

### Full Backup
```bash
# Create backup directory
mkdir -p backups/$(date +%Y%m%d)

# Backup database
docker-compose exec postgres pg_dump -U n8n n8n > backups/$(date +%Y%m%d)/database.sql

# Backup n8n data
docker cp $(docker-compose ps -q n8n):/home/node/.n8n backups/$(date +%Y%m%d)/n8n-data
```

### Restore
```bash
# Restore database
docker-compose exec -T postgres psql -U n8n -d n8n < backups/20240829/database.sql

# Restore n8n data
docker cp backups/20240829/n8n-data $(docker-compose ps -q n8n):/home/node/.n8n
docker-compose restart n8n
```

## 📞 Support

For issues and questions:
1. Check this troubleshooting guide
2. Review Docker Compose logs: `docker-compose logs`
3. Check service health: `docker-compose ps`
4. Verify environment configuration in `.env`

## 🎯 Next Steps

1. **Configure SMTP** for email notifications
2. **Set up workflows** in the n8n interface
3. **Configure integrations** with external services
4. **Monitor performance** and scale as needed
5. **Set up backups** for production use
