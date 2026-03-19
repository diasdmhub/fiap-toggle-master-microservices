# Microserviços "ToggleMaster" - Ambiente Local

A implantação do ToggleMaster em ambiente local utiliza arquivos de instruções `Dockerfile` e a ferramenta Docker Compose. Nesse ambiente, os microserviços do ToggleMaster serão implementados em imagens de containers e executados com o Compose. O objetivo desta etapa é demonstrar a integração dos componentes e a funcionalidade da aplicação.

<BR>

## 📋 Prerequisitos

- Copie o código-fonte dos microserviços e acesse o diretório `togglelocal`. Recomenda-se clonar este repositório com o **Git**.
- O terminal local deve estar autenticado na AWS com o [AWS CLI][awscli] para se conectar ao SQS e ao DynamoDB.
- É necessário uma ferramenta de gestão de containers como o [Docker][docker] ou o [Podman][podman].
- É necessário também utilizar a ferramenta [Docker Compose][dockercompose] ou o tradutor [Podman Compose][podmancompose].

<BR>

## 🛠️ Implementação

⚠️ **A implementação do sistema ToggleMaster em ambiente local envolve algumas etapas que devem ser seguidas atentamente. Devido às interdependências entre os microserviços, é recomendável avançar na ordem sugerida abaixo.**

> **Nesta demonstração utilizei o Podman. Altere o comando `podman` por `docker` caso esteja utilizando o Docker.**

<BR>

### 1. AWS

- **1.1** Siga para o seu ambiente AWS e [crie uma fila SQS padrão][criarsqs] com a política de acesso padrão. Guarde o nome dela (_sugestão `fiap-toggle-sqs-queue`_) e copie sua URL.

> **Opcionalmente, após criar a fila, os comandos abaixo capturam a URL da fila e a salvam nos arquivos de variáveis de ambiente apropriados.**

```bash
# Capturando a URL da fila
AWS_SQS_URL=$(aws sqs get-queue-url --queue-name fiap-toggle-sqs-queue --output text)

# Salvando a URL no arquivo .env
sed -i "s|^AWS_SQS_URL=.*|AWS_SQS_URL=\"$AWS_SQS_URL\"|" .env_evaluation
sed -i "s|^AWS_SQS_URL=.*|AWS_SQS_URL=\"$AWS_SQS_URL\"|" .env_analytics
```

- **1.2** Como sugerido no repositório [original `analytics-service`][analyticsserv], cria uma tabela no DynamoDB (_sugestão `fiap-toggle-dynamo-table`_).

```bash
# Crie a tabela no DynamoDB com o throughput mínimo
aws dynamodb create-table \
    --table-name fiap-toggle-dynamo-table \
    --attribute-definitions AttributeName=event_id,AttributeType=S \
    --key-schema AttributeName=event_id,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1

# Salvando o nome da tabela no arquivo .env
sed -i "s|^AWS_DYNAMODB_TABLE=.*|AWS_DYNAMODB_TABLE=\"fiap-toggle-dynamo-table\"|" .env_analytics
```

### 2. Variáveis

Cada microserviço possui um arquivo `.env_[serviço]` que é carregado pelo Docker Compose, cada um com as variáveis de ambiente apropriadas. As variáveis estão separadas por microserviço para evitar a atribuição desnecessária delas. Além dos microserviços, também é necessário configurar as variáveis de credenciais da AWS e do PostgreSQL local.

Preencha as variáveis de ambiente com os valores apropriados para cada microserviço, conforme os exemplos a seguir.

#### [➡️ `.env_aws`](./.env_aws)

> - É necessário incluir as [credenciais da console da AWS][awsauth] para que os containers consigam acessar os serviços da AWS.

#### [➡️ `.env_psql`](./.env_psql)

> - Utilize credenciais adequadas para o PostgreSQL.

#### [➡️ `.env_auth`](./.env_auth)

> - Utilize as credenciais do PostgreSQL na URL de conexão com o database.
> - Altere a senha "master" do `auth-service`.

#### [➡️ `.env_flag`](./.env_flag)

> - Utilize as credenciais do PostgreSQL na URL de conexão com o database.

#### [➡️ `.env_targeting`](./.env_targeting)

> - Utilize as credenciais do PostgreSQL na URL de conexão com o database.

#### [➡️ `.env_evaluation`](./.env_evaluation)

> - É necessário definir a chave de API após inicializar o `auth-service`.
> - Altere a região conforme utilizado na AWS.
> - Altere a URL da fila SQS conforme criada na AWS.

#### [➡️ `.env_analytics`](./.env_analytics)

> - Altere a região conforme utilizado na AWS.
> - Altere o nome da tabela do DynamoDB conforme criado na AWS.
> - Altere a URL da fila SQS conforme criada na AWS.

<BR>

### 3. Inicialização

Após ajustar todas as variáveis do ambiente, os microserviços podem ser inicializados.

- **3.1** Inicialize o ambiente com o comando a seguir. Ele fará o build e a execução das imagens dos microserviços.

```bash
podman compose up -d ; podman image prune -f
```

- **3.2** Verifique a execução dos containers com o comando a seguir. Todos devem apresentar o status `healthy`.

```bash
# podman ps -a
CONTAINER ID  IMAGE                                    COMMAND               CREATED        STATUS                  PORTS                   NAMES
4ce7d78cf1a5  docker.io/library/redis:alpine           redis-server          2 minutes ago  Up 2 minutes (healthy)  0.0.0.0:6379->6379/tcp  redis
d6d9b061410d  localhost/togglelocal_psql:latest        postgres              2 minutes ago  Up 2 minutes (healthy)  0.0.0.0:5432->5432/tcp  postgresql
63929b89f409  localhost/togglelocal_auth:latest        /app/auth.go          2 minutes ago  Up 2 minutes (healthy)  0.0.0.0:8001->8001/tcp  auth-service
39946dca6387  localhost/togglelocal_flag:latest        gunicorn --bind 0...  2 minutes ago  Up 2 minutes (healthy)  0.0.0.0:8002->8002/tcp  flag-service
94e2b3b1be34  localhost/togglelocal_targeting:latest   gunicorn --bind 0...  2 minutes ago  Up 2 minutes (healthy)  0.0.0.0:8003->8003/tcp  targeting-service
4f568400f4b2  localhost/togglelocal_evaluation:latest  /app/evaluation.g...  2 minutes ago  Up 2 minutes (healthy)  0.0.0.0:8004->8004/tcp  evaluation-service
a415d25cfc39  localhost/togglelocal_analytics:latest   gunicorn --bind 0...  2 minutes ago  Up 2 minutes (healthy)  0.0.0.0:8005->8005/tcp  analytics-service
```

- **3.3** Para enviar mensagens ao sistema ToggleMaster, é necessário autenticar o `evaluation-service` com uma chave de autenticação criada pelo microserviço de autenticação. Conforme o repositório [original do `auth-service`][authserv], gere um token com o comando a seguir.

> **Utilize no "header" do comando `curl` a mesma senha "master" salva no `.env_auth`.**

```bash
# Criação do token de API
curl -X POST http://localhost:8001/admin/keys \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer admin123" \
    -d '{"name": "evaluation-service"}'
# Resposta com o token
{
    "name": "evaluation-service",
    "key": "tm_key_37e1...",
    "message": "Guarde esta chave com segurança! Você não poderá vê-la novamente."
}
```

- **3.4** Salve a chave `tm_key_...` no arquivo de variáveis `.env_evaluation` do Evaluation Service (_`SERVICE_API_KEY="__CHAVE_DE_SERVICO__"`_), e reinicie os containers.

```bash
podman compose down && podman compose up -d
```

<BR>

### 4. Validação

Nesta etapa, o sistema ToggleMaster deve estar ativo e pronto para receber mensagens. Para validar seu funcionamento, é necessário criar uma chave de autenticação com o microserviço `auth-service`, uma "feature flag" com o microserviço `flag-service` e uma regra de segmentação com o microserviço `targeting-service`.

- **4.1** Crie a flag e sua regra de segmentação com os comandos a seguir.

```bash
# Criar chave de autenticação
FLAG_TOKEN=$(curl -X POST http://localhost:8001/admin/keys \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer SUA_MASTER_API" \
    -d '{"name": "toggle-flag"}' | sed -n 's/.*"key":"\([^"]*\)".*/\1/p')

# Criar feature flag com a chave 
curl -X POST http://localhost:8002/flags \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $FLAG_TOKEN" \
    -d '{
            "name": "enable-feature",
            "description": "Ativa o novo recurso para os usuários",
            "is_enabled": true
        }'

# Criar uma regra de segmentação
curl -X POST http://localhost:8003/rules \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $FLAG_TOKEN" \
    -d '{
            "flag_name": "enable-feature",
            "is_enabled": true,
            "rules": {
                "type": "PERCENTAGE",
                "value": 50
            }
        }'
```

- **4.2** Envie mensagens para o ToggleMaster. Neste teste, são enviadas **1.000** mensagens, que são enfileiradas no SQS. O `analytics-service` processa as mensagens, enviando-as para a tabela do DynamoDB. Nesse momento, é possível observar o enfileiramento de mensagens no SQS e as mensagens sendo gravadas no DynamoDB. Utilize o console da AWS para isso.

    > ⚠️ **Este teste envia muitas mensagens ao ToggleMaster e pode gerar um alto processamento em seu dispositivo. Ele também pode levar um tempo, pois o serviço precisa se comunicar com a AWS. Se preferir, basta reduzir o número de mensagens enviadas para acelerar o processo.**

```bash
for i in $(seq 1000); do { curl "http://localhost:8004/evaluate?user_id=teste-$i&flag_name=enable-feature" ; } done
```

- Opcionalmente, é possível observar as mensagens sendo processadas no log do `analytics-service`, o que pode levar um tempo.

```bash
podman logs -f analytics-service
```

<BR>

## 🤔 Observação

- ℹ️ Apesar da implementação ocorrer em ambiente local, ela também utiliza os recursos SQS e DynamoDB da AWS pois os códigos originais não foram preparados para outras opções.

[awscli]: https://aws.amazon.com/cli/
[docker]: https://docs.docker.com/
[podman]: https://podman.io/docs
[dockercompose]: https://docs.docker.com/compose/
[podmancompose]: https://github.com/containers/podman-compose
[awsauth]: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sign-in.html
[criarsqs]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/creating-sqs-standard-queues.html
[analyticsserv]: https://github.com/FIAP-TCs/analytics-service
[authserv]: https://github.com/FIAP-TCs/auth-service