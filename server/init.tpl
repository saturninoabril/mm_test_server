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
    make

export HOME=/home/ubuntu

# Install docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Docker login
echo ${docker_password} | sudo docker login --username ${docker_username} --password-stdin

# Set feature flags
export MM_FEATUREFLAGS_CUSTOMDATARETENTIONENABLED=true

# Set DB config
export MM_SQLSETTINGS_DRIVERNAME="postgres"
export MM_SQLSETTINGS_DATASOURCE="postgres://mmuser:mostest@mm-db:5432/mattermost_test?sslmode=disable&connect_timeout=10"

cd ~/
mkdir docker-compose
curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/server/docker-compose/docker-compose.yml --output ~/docker-compose/docker-compose.yml
curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/server/docker-compose/docker-compose.common.yml --output ~/docker-compose/docker-compose.common.yml
cd docker-compose && mkdir docker
curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/server/docker-compose/docker/postgres.conf --output ~/docker-compose/docker/postgres.conf
curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/server/docker-compose/docker/test-data.ldif --output ~/docker-compose/docker/test-data.ldif
cd docker && mkdir keycloak
curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/server/docker-compose/docker/keycloak/realm.json --output ~/docker-compose/docker/keycloak/realm.json

if "${with_elasticsearch}" -eq "true"; then
    # Run Elasticsearch
    sudo docker run -d \
        --name mm-elasticsearch \
        -p 9200:9200 \
        -e http.host="0.0.0.0" \
        -e http.port=9200 \
        -e http.cors.enabled="true" \
        -e http.cors.allow-origin="http://localhost:1358,http://127.0.0.1:1358" \
        -e http.cors.allow-headers="X-Requested-With,X-Auth-Token,Content-Type,Content-Length,Authorization" \
        -e http.cors.allow-credentials="true" \
        -e transport.host="127.0.0.1" \
        -e ES_JAVA_OPTS="-Xmx1024m -Xms1024m" \
        mattermost/mattermost-elasticsearch-docker:6.5.1

    until curl --max-time 5 --output - http://localhost:9200; do echo waiting for app; sleep 5; done;
fi

# Run PostgreSQL DB
sudo docker run -d \
    --name mm-db \
    -p 5432:5432 \
    -e POSTGRES_USER=mmuser \
    -e POSTGRES_PASSWORD=mostest \
    -e POSTGRES_DB=mattermost_test \
    -v "$HOME/docker-compose/docker/postgres.conf":/etc/postgresql/postgresql.conf \
    postgres:10

sudo docker run -d \
    --name mm-inbucket \
    -p 10025:10025 \
    -p 10080:10080 \
    -p 10110:10110 \
    mattermost/inbucket:release-1.2.0

sudo docker run -d \
    --name mm-openldap \
    -p 389:389 \
    -p 636:636 \
    -e LDAP_TLS_VERIFY_CLIENT="never" \
    -e LDAP_ORGANISATION="Mattermost Test" \
    -e LDAP_DOMAIN="mm.test.com" \
    -e LDAP_ADMIN_PASSWORD="mostest" \
    osixia/openldap:1.4.0

cd ~/
mkdir mattermost_config
mkdir mattermost_data
curl https://raw.githubusercontent.com/saturninoabril/mm_test_server/main/server/mattermost/config.json --output ~/mattermost_config/config.json

echo "Modify config"
jq '.ElasticsearchSettings.ConnectionUrl = "http://mm-elasticsearch:9200"' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
jq '.ElasticsearchSettings.EnableIndexing = true' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
jq '.ElasticsearchSettings.EnableSearching = true' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
jq '.ElasticsearchSettings.EnableAutocomplete = true' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
jq '.ElasticsearchSettings.Sniff = false' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
jq '.ServiceSettings.ListenAddress = ":8065"' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
jq '.ServiceSettings.SiteURL = "http://${app_instance_url}:8065"' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
jq '.TeamSettings.MaxUsersPerTeam = 2000' ~/mattermost_config/config.json|sponge ~/mattermost_config/config.json
sleep 5

sudo chown -R 2000:2000 ~/mattermost_config/
sudo chown -R 2000:2000 ~/mattermost_data/

cd ~/mattermost_config
touch mattermost.mattermost-license
echo ${license} > mattermost.mattermost-license

# Run Mattermost mm-app
if "${with_elasticsearch}" -eq "true"; then
    echo "Start mm-app with mm-elasticsearch"
    sudo docker run -d \
        --name mm-app \
        --link mm-db \
        --link mm-openldap \
        --link mm-inbucket \
        --link mm-elasticsearch \
        -p 8065:8065 \
        -e MM_CLUSTERSETTINGS_READONLYCONFIG=false \
        -e MM_EMAILSETTINGS_SMTPSERVER=mm-inbucket \
        -e MM_LDAPSETTINGS_LDAPSERVER=mm-openldap \
        -e MM_PLUGINSETTINGS_ENABLEUPLOADS=true \
        -e MM_SQLSETTINGS_DRIVERNAME=$MM_SQLSETTINGS_DRIVERNAME \
        -e MM_SQLSETTINGS_DATASOURCE=$MM_SQLSETTINGS_DATASOURCE \
        -e MM_FEATUREFLAGS_CUSTOMDATARETENTIONENABLED=$MM_FEATUREFLAGS_CUSTOMDATARETENTIONENABLED \
        -v $HOME/mattermost_config:/mattermost/config \
        -v $HOME/mattermost_data:/mattermost/data \
        mattermost/${mattermost_docker_image}:${mattermost_docker_tag}
else
    echo "Start mm-app without elasticsearch"
    sudo docker run -d \
        --name mm-app \
        --link mm-db \
        --link mm-openldap \
        --link mm-inbucket \
        -p 8065:8065 \
        -e MM_CLUSTERSETTINGS_READONLYCONFIG=false \
        -e MM_EMAILSETTINGS_SMTPSERVER=mm-inbucket \
        -e MM_LDAPSETTINGS_LDAPSERVER=mm-openldap \
        -e MM_PLUGINSETTINGS_ENABLEUPLOADS=true \
        -e MM_SQLSETTINGS_DRIVERNAME=$MM_SQLSETTINGS_DRIVERNAME \
        -e MM_SQLSETTINGS_DATASOURCE=$MM_SQLSETTINGS_DATASOURCE \
        -e MM_FEATUREFLAGS_CUSTOMDATARETENTIONENABLED=$MM_FEATUREFLAGS_CUSTOMDATARETENTIONENABLED \
        -v $HOME/mattermost_config:/mattermost/config \
        -v $HOME/mattermost_data:/mattermost/data \
        mattermost/${mattermost_docker_image}:${mattermost_docker_tag}
fi

# Run MinIO object storage
sudo docker run -d \
    --name mm-minio \
    -p 9000:9000 \
    -e MINIO_ACCESS_KEY=minioaccesskey \
    -e MINIO_SECRET_KEY=miniosecretkey \
    -e MINIO_SSE_MASTER_KEY="my-minio-key:6368616e676520746869732070617373776f726420746f206120736563726574" \
    minio/minio:RELEASE.2019-10-11T00-38-09Z server /data

sudo docker exec mm-minio sh -c 'mkdir -p /data/mattermost-test'

if "${with_keycloak}" -eq "true"; then
    echo "Run Keycloak for SAML"
    # Run Keycloak for SAML
    sudo docker run -d --name mm-keycloak -p 8484:8080 -e KEYCLOAK_USER=mmuser -e KEYCLOAK_PASSWORD=mostest -e DB_VENDOR=h2 jboss/keycloak:10.0.2

    sleep 10
fi

# Install node
cd ~/
curl -sL https://deb.nodesource.com/setup_14.x -o nodesource_setup.sh
sudo bash nodesource_setup.sh
sudo apt install nodejs
node -v
npm -v

cd ~/
# git clone --depth 1  --branch master https://github.com/mattermost/mattermost-webapp.git mattermost-webapp
git clone --depth 1  --branch fix-oauth https://github.com/saturninoabril/mattermost-cypress-docker mattermost-webapp

mkdir -p mm-e2e-webhook/cypress/plugins
mkdir -p mm-e2e-webhook/utils
cp mattermost-webapp/e2e/cypress/plugins/post_message_as.js mm-e2e-webhook/cypress/plugins/post_message_as.js
cp mattermost-webapp/e2e/utils/webhook_utils.js mm-e2e-webhook/utils/webhook_utils.js
cp mattermost-webapp/e2e/webhook_serve.js mm-e2e-webhook/webhook_serve.js
cd mm-e2e-webhook
npm install axios express client-oauth2@larkox/js-client-oauth2#e24e2eb5dfcbbbb3a59d095e831dbe0012b0ac49
nohup node webhook_serve.js > output.log &

sudo docker exec mm-app sh -c 'mattermost sampledata -w 4 -u 60'
# sudo docker restart mm-app
sleep 10

echo "Show config after restart"
sudo docker exec mm-app sh -c 'mattermost config show'

cd ~/
ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest -H ldap://localhost:389 -f docker-compose/docker/test-data.ldif -c

if "${with_keycloak}" -eq "true"; then
    sudo docker exec mm-keycloak bash -c 'cd $HOME/keycloak/bin && ./kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user mmuser --password mostest'
    sleep 10
    sudo docker exec mm-keycloak bash -c 'cd $HOME/keycloak/bin && ./kcadm.sh update realms/master -s sslRequired=NONE'

    sudo docker restart mm-keycloak
fi

sudo docker restart mm-app
sleep 10
until curl --max-time 5 --output - http://localhost:8065; do echo waiting for mm-app; sleep 5; done;
