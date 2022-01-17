#! /bin/bash
sudo apt-get update
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common \
    moreutils \
    jq \
    ldap-utils \
    gcc \
    g++ \
    make \
    unzip

export HOME=/home/ubuntu

# Install docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Docker login
echo ${docker_password} | sudo docker login --username ${docker_username} --password-stdin

cd $HOME

# -----------------
# Run PostgreSQL DB
# -----------------

# Download database config
curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/rfqa-cloud-server/postgres.conf --output $HOME/postgres.conf

# Set DB config
export PG_USER="mmuser"
export PG_PASSWORD="mostest"
export PG_DATABASE="mattermost_test"
export MM_SQLSETTINGS_DRIVERNAME="postgres"
export MM_SQLSETTINGS_DATASOURCE="postgres://$PG_USER:$PG_PASSWORD@mm-db:5432/$PG_DATABASE?sslmode=disable&connect_timeout=10"

sudo docker run -d \
    --name mm-db \
    -p 5432:5432 \
    -e POSTGRES_USER=$PG_USER \
    -e POSTGRES_PASSWORD=$PG_PASSWORD \
    -e POSTGRES_DB=$PG_DATABASE \
    -v "$HOME/postgres.conf":/etc/postgresql/postgresql.conf \
    postgres:10

# -----------------
# Run Inbucket as email service
# -----------------

sudo docker run -d \
    --name mm-inbucket \
    -p 10025:10025 \
    -p 10080:10080 \
    -p 10110:10110 \
    mattermost/inbucket:release-1.2.0

# -----------------
# Run LDAP
# -----------------

sudo docker run -d \
    --name mm-openldap \
    -p 389:389 \
    -p 636:636 \
    -e LDAP_TLS_VERIFY_CLIENT="never" \
    -e LDAP_ORGANISATION="Mattermost Test" \
    -e LDAP_DOMAIN="mm.test.com" \
    -e LDAP_ADMIN_PASSWORD="mostest" \
    osixia/openldap:1.4.0

# -----------------
# Run Mattermost server
# -----------------

# Download server configuration
mkdir mattermost_config
curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/rfqa-cloud-server/mattermost_config.json --output $HOME/mattermost_config/config.json

# Give user permission to folders
sudo chown -R 2000:2000 $HOME/mattermost_config/
mkdir $HOME/mattermost_data
sudo chown -R 2000:2000 $HOME/mattermost_data/

# Generate license
cd $HOME/mattermost_config
touch mattermost.mattermost-license
echo ${license} > mattermost.mattermost-license

# Set env variables
cd ~/mattermost_config
env_file=mm_req.env
touch $env_file

if [ -z "${mm_env}" ]
then
  echo "No env variable from the request"
else
  echo "Received: ${mm_env}"

  envarr=$(echo ${mm_env} | tr "," "\n")
  for env in $envarr; do echo "> [$env]"; echo "$env" >> $env_file; done;
fi

echo "MM_CLUSTERSETTINGS_READONLYCONFIG=false" >> $env_file
echo "MM_EMAILSETTINGS_SMTPSERVER=mm-inbucket" >> $env_file
echo "MM_LDAPSETTINGS_LDAPSERVER=mm-openldap" >> $env_file
echo "MM_PLUGINSETTINGS_ENABLEUPLOADS=true" >> $env_file
echo "MM_SQLSETTINGS_DRIVERNAME=$MM_SQLSETTINGS_DRIVERNAME" >> $env_file
echo "MM_SQLSETTINGS_DATASOURCE=$MM_SQLSETTINGS_DATASOURCE" >> $env_file
echo "MM_CLOUD_API_KEY=${cloud_api_key}" >> $env_file
echo "MM_CUSTOMER_ID=${cloud_customer_id}" >> $env_file
echo "MM_CLOUD_INSTALLATION_ID=${cloud_installation_id}" >> $env_file

echo "Start mm-app"
sudo docker run -d \
    --name mm-app \
    --link mm-db \
    --link mm-openldap \
    --link mm-inbucket \
    -p 8065:8065 \
    --env-file $HOME/mattermost_config/$env_file \
    -v $HOME/mattermost_config:/mattermost/config \
    -v $HOME/mattermost_data:/mattermost/data \
    mattermost/${mattermost_docker_image}:${mattermost_docker_tag}

# -----------------
# Run MinIO object storage
# -----------------

sudo docker run -d \
    --name mm-minio \
    -p 9000:9000 \
    -e MINIO_ACCESS_KEY=minioaccesskey \
    -e MINIO_SECRET_KEY=miniosecretkey \
    -e MINIO_SSE_MASTER_KEY="my-minio-key:6368616e676520746869732070617373776f726420746f206120736563726574" \
    minio/minio:RELEASE.2019-10-11T00-38-09Z server /data

sudo docker exec mm-minio sh -c 'mkdir -p /data/mattermost-test'

# -----------------
# Load LDAP test data
# -----------------

# Download LDAP test data
curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/rfqa-cloud-server/test-data.ldif --output $HOME/test-data.ldif

cd $HOME
ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest -H ldap://localhost:389 -f $HOME/test-data.ldif -c

# -----------------
# Restart Mattermost server
# -----------------

echo "Show config then restart"
sudo docker exec mm-app sh -c 'mattermost config show'

sudo docker restart mm-app
sleep 10
until curl --max-time 5 --output - http://localhost:8065; do echo waiting for mm-app; sleep 5; done;

# -----------------
# Create initial data
# -----------------

echo "Install deno"
curl -fsSL https://deno.land/x/install/install.sh | sh

export DENO_INSTALL="/home/ubuntu/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"
deno --version

deno run --allow-net https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/rfqa-cloud-server/init_server.ts

# Update server configuration
jq '.ServiceSettings.ListenAddress = ":8065"' $HOME/mattermost_config/config.json|sponge $HOME/mattermost_config/config.json
jq '.ServiceSettings.SiteURL = "http://${app_instance_url}:8065"' $HOME/mattermost_config/config.json|sponge $HOME/mattermost_config/config.json
jq '.CloudSettings.CWSUrl = "${cloud_cws_url}"' $HOME/mattermost_config/config.json|sponge $HOME/mattermost_config/config.json
jq '.CloudSettings.CWSAPIUrl = "${cloud_cws_url}"' $HOME/mattermost_config/config.json|sponge $HOME/mattermost_config/config.json
jq '.ExperimentalSettings.RestrictSystemAdmin = true' $HOME/mattermost_config/config.json|sponge $HOME/mattermost_config/config.json
sleep 5

echo "Show config then restart"
sudo docker exec mm-app sh -c 'mattermost config show'

sudo docker restart mm-app
sleep 10
until curl --max-time 5 --output - http://localhost:8065; do echo waiting for mm-app; sleep 5; done;

echo "Done"
