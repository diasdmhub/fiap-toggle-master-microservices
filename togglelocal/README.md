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

⚠️ **A implementação do sistema ToggleMaster envolve algumas etapas que devem ser seguidas atentamente. Devido às interdependências entre os microserviços, é recomendável avançar na ordem sugerida abaixo.**

<BR>

### 1. Variáveis

Cada microserviço possui um arquivo `.env_[serviço]` que é carregado pelo Docker Compose, cada um com as variáveis de ambiente apropriadas. As variáveis estão separadas por microserviço para evitar a atribuição desnecessária delas. Além dos microserviços, também é necessário configurar as variáveis de credenciais da AWS e do PostgreSQL local.

Preencha as variáveis de ambiente com os valores apropriados para cada microserviço, conforme os exemplos a seguir.

#### [➡️ `.env_aws`](./.env_aws)

> - É necessário obter as [credenciais da console da AWS][awsauth].

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

Após ajustar todas as variáveis do ambiente, os microserviços já podem ser incializados. Entretanto, é necessário configurar uma chave de autenticação a partir do microserviço de autenticação.

[awscli]: https://aws.amazon.com/cli/
[docker]: https://docs.docker.com/
[podman]: https://podman.io/docs
[dockercompose]: https://docs.docker.com/compose/
[podmancompose]: https://github.com/containers/podman-compose
[awsauth]: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sign-in.html