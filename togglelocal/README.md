# Microserviços "ToggleMaster" - Ambiente Local

A implantação do ToggleMaster em ambiente local utiliza arquivos de instruções `Dockerfile` e a ferramenta Docker Compose. Nesse ambiente, os microserviços do ToggleMaster serão implementados em imagens de containers e executados com o Compose. O objetivo desta etapa é demonstrar a integração dos componentes e a funcionalidade da aplicação.

<BR>

## Prerequisitos

- Copie o código-fonte dos microserviços. Recomenda-se clonar este repositório com o **Git**.
- O terminal local deve estar autenticado na AWS com o [AWS CLI][awscli] para se conectar ao SQS e ao DynamoDB.
- É necessário uma ferramenta de gestão de containers como o [Docker][docker] ou o [Podman][podman].
- É necessário também utilizar a ferramenta [Docker Compose][dockercompose] ou o tradutor [Podman Compose][podmancompose].

<BR>

## Implementação

⚠️ **A implementação do sistema ToggleMaster em ambiente local envolve algumas etapas que devem ser seguidas atentamente. Devido às interdependências entre os microserviços, é recomendável avançar na ordem sugerida abaixo.**

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

> - É necessário obter as [credenciais da console da AWS][awsauth] para que os containers consigam acessar os serviços da AWS.

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

### 2. Inicialização

Após ajustar todas as variáveis do ambiente, os microserviços podem ser incializados.

- **2.1** Inicalize o ambiente com o comando abaixo. Ele fara o build e a execução das imagens dos microserviços.

```bash
podman compose up -d ; podman image prune -f
```

- **2.2** Verifique a execução dos containers com o comando abaixo `podman ps -a`. Todos devem ter o status `healthy`.

```bash
CONTAINER ID  IMAGE                                    COMMAND               CREATED        STATUS                  PORTS                   NAMES
4ce7d78cf1a5  docker.io/library/redis:alpine           redis-server          2 minutes ago  Up 2 minutes (healthy)  0.0.0.0:6379->6379/tcp  redis
d6d9b061410d  localhost/togglelocal_psql:latest        postgres              2 minutes ago  Up 2 minutes (healthy)  0.0.0.0:5432->5432/tcp  postgresql
63929b89f409  localhost/togglelocal_auth:latest        /app/auth.go          2 minutes ago  Up 2 minutes (healthy)  0.0.0.0:8001->8001/tcp  auth-service
39946dca6387  localhost/togglelocal_flag:latest        gunicorn --bind 0...  2 minutes ago  Up 2 minutes (healthy)  0.0.0.0:8002->8002/tcp  flag-service
94e2b3b1be34  localhost/togglelocal_targeting:latest   gunicorn --bind 0...  2 minutes ago  Up 2 minutes (healthy)  0.0.0.0:8003->8003/tcp  targeting-service
4f568400f4b2  localhost/togglelocal_evaluation:latest  /app/evaluation.g...  2 minutes ago  Up 2 minutes (healthy)  0.0.0.0:8004->8004/tcp  evaluation-service
a415d25cfc39  localhost/togglelocal_analytics:latest   gunicorn --bind 0...  2 minutes ago  Up 2 minutes (healthy)  0.0.0.0:8005->8005/tcp  analytics-service
```

- **2.3** Para enviar mensagens ao sistema ToggleMaster, é necessário configurar uma chave de autenticação a partir do microserviço de autenticação. Conforme o repositório original do `auth-service`, gere um token com o comando abaixo. Guarde o nome do serviço criado e seu token.

> **Utilize no "header" do comando `curl` a mesma senha "master" salva no `.env_auth`.**

```bash
# Criação do token de API
curl -X POST http://localhost:8001/admin/keys \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer admin123" \
    -d '{"name": "admin-service"}'
# Resposta com o token
{
    "name": "admin-service",
    "key": "tm_key_37e1...",
    "message": "Guarde esta chave com segurança! Você não poderá vê-la novamente."
}
```

- **2.4** Salve a chave `tm_key_...` no arquivo de variáveis `.env_evaluation` do Evaluation Service (_SERVICE_API_KEY="__CHAVE_DE_SERVICO__"_), e reinicie todos os containers.

```bash
podman compose down && podman compose up -d
```

[awscli]: https://aws.amazon.com/cli/
[docker]: https://docs.docker.com/
[podman]: https://podman.io/docs
[dockercompose]: https://docs.docker.com/compose/
[podmancompose]: https://github.com/containers/podman-compose
[awsauth]: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sign-in.html
[criarsqs]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/creating-sqs-standard-queues.html
[analyticsserv]: https://github.com/FIAP-TCs/analytics-service