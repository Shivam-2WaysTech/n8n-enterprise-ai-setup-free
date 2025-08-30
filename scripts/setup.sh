#!/bin/bash

# ============================================================================
# n8n Local Development Setup Script
# ============================================================================
# This script automates the initial setup of n8n for local development

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to generate encryption key
generate_encryption_key() {
    if command_exists openssl; then
        openssl rand -base64 32 | tr -d '\n'
    else
        # Fallback method using /dev/urandom
        head -c 32 /dev/urandom | base64 | tr -d '\n'
    fi
}

# Function to generate random password
generate_password() {
    local length=${1:-16}
    if command_exists openssl; then
        openssl rand -base64 $length | tr -d '\n' | head -c $length
    else
        head -c $length /dev/urandom | base64 | tr -d '\n' | head -c $length
    fi
}

print_status "Starting n8n Local Development Setup..."

# Check prerequisites
print_status "Checking prerequisites..."

if ! command_exists docker; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command_exists docker-compose; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

print_success "Prerequisites check passed"

# Check if .env file exists
if [ -f ".env" ]; then
    print_warning ".env file already exists"
    read -p "Do you want to backup and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mv .env .env.backup.$(date +%Y%m%d_%H%M%S)
        print_status "Backed up existing .env file"
    else
        print_status "Using existing .env file"
        exit 0
    fi
fi

# Copy .env.example to .env
if [ -f ".env.example" ]; then
    cp .env.example .env
    print_success "Created .env file from template"
else
    print_error ".env.example file not found"
    exit 1
fi

# Generate secure values
print_status "Generating secure configuration values..."

ENCRYPTION_KEY=$(generate_encryption_key)
POSTGRES_PASSWORD=$(generate_password 20)
REDIS_PASSWORD=$(generate_password 16)
BASIC_AUTH_PASSWORD=$(generate_password 12)

# Update .env file with generated values
sed -i.bak "s/REPLACE-WITH-32-CHAR-ENCRYPTION-KEY/$ENCRYPTION_KEY/" .env
sed -i.bak "s/change-this-password/$POSTGRES_PASSWORD/" .env
sed -i.bak "s/change-this-redis-password/$REDIS_PASSWORD/" .env
sed -i.bak "s/your-secure-password/$BASIC_AUTH_PASSWORD/" .env

# Remove backup file
rm .env.bak

print_success "Generated and configured secure values"

# Display configuration summary
echo
print_status "Configuration Summary:"
echo "=========================="
echo "Database Password: $POSTGRES_PASSWORD"
echo "Redis Password: $REDIS_PASSWORD"
echo "Basic Auth Password: $BASIC_AUTH_PASSWORD"
echo "Encryption Key: ${ENCRYPTION_KEY:0:10}... (truncated for security)"
echo
print_warning "Please save these credentials securely!"
echo

# Ask about SMTP configuration
echo
read -p "Do you want to configure SMTP email settings now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    print_status "SMTP Configuration"
    echo "=================="
    echo "1. Gmail (recommended for development)"
    echo "2. Outlook/Hotmail"
    echo "3. Yahoo Mail"
    echo "4. Custom SMTP"
    echo "5. Skip for now"
    echo
    read -p "Choose SMTP provider (1-5): " -n 1 -r smtp_choice
    echo
    
    case $smtp_choice in
        1)
            print_status "Configuring Gmail SMTP..."
            read -p "Enter your Gmail address: " gmail_user
            read -p "Enter your Gmail App Password: " gmail_pass
            
            sed -i.bak "s/your-email@gmail.com/$gmail_user/" .env
            sed -i.bak "s/your-gmail-app-password/$gmail_pass/" .env
            rm .env.bak
            
            print_success "Gmail SMTP configured"
            print_warning "Make sure you have enabled 2FA and generated an App Password"
            ;;
        2|3|4)
            print_status "Please manually configure SMTP settings in the .env file"
            ;;
        5)
            print_status "Skipping SMTP configuration"
            ;;
        *)
            print_warning "Invalid choice, skipping SMTP configuration"
            ;;
    esac
fi

# Create scripts directory if it doesn't exist
mkdir -p scripts

print_success "Setup completed successfully!"
echo
print_status "Next steps:"
echo "1. Review and customize .env file if needed"
echo "2. Run: docker-compose up -d"
echo "3. Access n8n at: http://localhost:5678"
echo "4. Check setup with: ./scripts/health-check.sh"
echo
print_status "For detailed instructions, see SETUP.md"
