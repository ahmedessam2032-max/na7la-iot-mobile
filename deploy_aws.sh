#!/bin/bash
# =====================================================================
# Na7la IoT v2.0 - One-Click AWS EC2 Deployment Script
# Target: Ubuntu 24.04 / 26.04 AMD64 on AWS EC2 (t3.micro)
# =====================================================================

set -e

echo "🚀 [1/5] Checking system prerequisites..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "📦 [2/5] Docker not found. Installing Docker engine..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker $USER
    echo "✅ Docker installed successfully."
else
    echo "✅ [2/5] Docker is already installed."
fi

# Prepare persistent data directory
echo "📁 [3/5] Setting up persistent storage..."
mkdir -p ./data
if [ -f "na7la_iot.db" ] && [ ! -f "./data/na7la_iot.db" ]; then
    echo "Copying existing na7la_iot.db into ./data/..."
    cp na7la_iot.db ./data/na7la_iot.db
fi

# Build & launch container
echo "🏗️  [4/5] Building and starting Na7la IoT containers..."
sudo docker compose down --remove-orphans || true
sudo docker compose up -d --build

# Verify health
echo "⏳ [5/5] Verifying service health..."
sleep 5
for i in {1..10}; do
    if curl -s http://localhost:8080/api/v1/health | grep -q "healthy"; then
        echo "🎉 Na7la IoT v2.0 is LIVE and HEALTHY on AWS!"
        echo "🌐 Dashboard URL: http://$(curl -s ifconfig.me):8080"
        echo "⚡ Hardware TCP Hub listening on port: 10086"
        exit 0
    fi
    echo "Waiting for backend to boot ($i/10)..."
    sleep 3
done

echo "⚠️ Container started. Showing logs:"
sudo docker compose logs --tail=20
