# Microserviços "ToggleMaster" - Ambiente Kubernetes (EKS)

A implantação do ToggleMaster no Kubernetes utiliza arquivos de configuração para criar o cluster e arquivos de instrução chamados "manifestos" para os microserviços. Nesse ambiente, os microserviços do ToggleMaster serão implementados por meio de "deployments" e executados em "pods" do Kubernetes. O objetivo desta etapa é demonstrar a integração dos componentes em ambientes "cloud" e o autoescalonamento com do sistema ToggleMaster.

<BR>

## 📋 Prerequisitos

- Copie o código-fonte dos microserviços e acesse o diretório `togglekube`. Recomenda-se clonar este repositório com o **Git**.
    - `git clone https://github.com/diasdmhub/fiap-toggle-master-microservices.git && cd fiap-toggle-master-microservices/kube`
- O terminal local deve estar autenticado na AWS com o [AWS CLI][awscli].
- É necessário utilizar a ferramenta [Docker Compose][dockercompose] ou o tradutor [Podman Compose][podmancompose].
- Cliente PostgreSQL.
- O `kubectl` é necessário para gerenciar o cluster Kubernetes e seus recursos. Recomenda-se instalá-lo utilizando o [repositório oficial do Kubernetes][kuberepo].

<BR>

## 🛠️ Roteiro de Implementação

⚠️ **A implementação do sistema ToggleMaster em ambiente Kubernetes envolve algumas etapas que devem ser seguidas atentamente. Devido às interdependências entre os microserviços, é recomendável avançar na ordem sugerida abaixo.**

> **Nesta demonstração, foi utilizado o Podman. Altere o comando `podman` por `docker` caso esteja utilizando o Docker.**

<BR>

### 1. Preparação dos Serviços AWS

- **1.1** Defina uma região padrão da AWS para o seu ambiente. Essa região será utilizada em diversos parâmetros posteriormente.

- ⚠️ **Este repositório está definido para a região `us-east-1` por padrão. Se necessário, altere a região na configuração do AWS CLI.**

> **O comando a seguir captura a região definida para o ambiente AWS.**

```bash
AWS_REGION=$(aws configure get region)
sed -i "s|  AWS_REGION: .*|  AWS_REGION: \"$AWS_REGION\"|" manifest/060-evaluation-service/061-configmap.yaml
sed -i "s|  AWS_REGION: .*|  AWS_REGION: \"$AWS_REGION\"|" manifest/070-analytics-service/071-configmap.yaml
```

<BR>

- **1.2** As imagens dos microserviços criadas no [ambiente local][ambientelocal] devem ser enviadas ao repositório de imagens da AWS, o ECR.

Caso as imagens ainda não tenham sido criadas, **acesse para o diretório `local`** deste repositório e crie as imagens dos microserviços.

```bash
# Build da imagens
for serv in "auth" "flag" "targeting" "evaluation" "analytics"; do
    podman build -f Dockerfile-${serv} -t toggle/${serv}-service .
done

# Limpeza das imagens
podman image prune -f
```

O build deve gerar imagens com nomes similares ao exemplo abaixo.

```bash
# podman images
REPOSITORY                           TAG         IMAGE ID      CREATED        SIZE
localhost/toggle/analytics-service   latest      81591b4ee04b  7 minutes ago  93.8 MB
localhost/toggle/evaluation-service  latest      c82df1c57874  7 minutes ago  20.8 MB
localhost/toggle/targeting-service   latest      b68763941f28  8 minutes ago  79.3 MB
localhost/toggle/flag-service        latest      6fe426b19fd0  8 minutes ago  79.3 MB
localhost/toggle/auth-service        latest      043104410a81  8 minutes ago  17.5 MB
docker.io/library/golang             alpine      e951cd8dd18b  2 weeks ago    254 MB
docker.io/library/python             3-alpine    c7ed750fc366  6 weeks ago    49.8 MB
docker.io/library/alpine             latest      a40c03cbb81c  7 weeks ago    8.74 MB
```

Crie os repositórios da AWS (_sugestão `toggle/[serviço]`_) e envie as respectivas imagens.

```bash
# Capturar o ID do usuário
ACC_ID=$(aws sts get-caller-identity --query Account --output text)

# Autenticar o gerenciador de containers local (Docker/Podman) na AWS
aws ecr get-login-password | podman login --username AWS --password-stdin ${ACC_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
# Login Succeeded!

# Criar os repositórios dos microserviços
for serv in "auth" "flag" "targeting" "evaluation" "analytics"; do
    aws ecr create-repository \
        --repository-name "toggle/${serv}-service" \
        --image-tag-mutability MUTABLE \
        --encryption-configuration encryptionType=AES256 \
        --tags Key=Toggle,Value=ECR Key=Servico,Value=${serv}

# Enviar as imagens à AWS
    sleep 2
    podman tag toggle/${serv}-service:latest ${ACC_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/toggle/${serv}-service:latest
    docker push ${ACC_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/toggle/${serv}-service:latest
done
```

Retorne ao diretório `kube` e atualize os deployments de cada microserviço com a URI dos repositórios criados.

```bash
for serv in "auth" "flag" "targeting" "evaluation" "analytics"; do
    sed -E -i "s|^\s+image: .*|        image: ${ACC_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/toggle/${serv}-service:latest|" manifest/0*0-${serv}-service/*-deployment.yaml
done
```

<BR>

- **1.3** [Crie uma fila SQS padrão][criarsqs]. Guarde o nome dela (_sugestão `fiap-toggle-sqs-queue`_) e copie sua URL.

> **Os comandos a seguir criam a fila, capturam sua URL da fila e a salvam nos arquivos de manifesto apropriados.**

```bash
# Criar uma fila SQS padrão
SQS_NAME="fiap-toggle-sqs-queue"
aws sqs create-queue \
    --queue-name "$SQS_NAME" \
    --attributes VisibilityTimeout=30,MessageRetentionPeriod=3600

# Capturando a URL da fila
AWS_SQS_URL=$(aws sqs get-queue-url --queue-name $SQS_NAME --output text)

# Salvando a URL no manifesto secrets SQS
sed -i "s@  AWS_SQS_URL: .*@  AWS_SQS_URL: $(echo -n "$AWS_SQS_URL" | base64 -w 0)@" manifest/020-secrets-sqs.yaml
```

<BR>

- **1.4** Como sugerido no repositório [original `analytics-service`][analyticsserv], crie uma tabela no DynamoDB (_sugestão `fiap-toggle-dynamo-table`_).

> **Os comandos a seguir criam a tabela com os parâmetros apropriados, e salvam seu nome nos arquivos de manifesto apropriados.**

```bash
# Crie a tabela no DynamoDB com o throughput mínimo
DYNAMO_NAME="fiap-toggle-dynamo-table"
aws dynamodb create-table \
    --table-name "$DYNAMO_NAME" \
    --attribute-definitions AttributeName=event_id,AttributeType=S \
    --key-schema AttributeName=event_id,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1

# Salvando o nome da tabela no manifesto do analytics-service
sed -i "s|^\s\sAWS_DYNAMODB_TABLE: .*|  AWS_DYNAMODB_TABLE: \"$DYNAMO_NAME\"|" manifest/070-analytics-service/071-configmap.yaml
```

<BR>

### 2. Cluster EKS

Após criar os serviços acima na AWS, é possível inicializar o cluster Kubernetes com a ferramenta `eksctl`, pois ela facilita a criação e a configuração do cluster.

Os parâmetros do cluster estão no arquivo `cluster.yaml`, que já possui os valores ajustados para este ambiente (_sugestão: `fiap-toggle-eks-cluster`_). Caso queira, altere os valores neste arquivo.

> ⚠️ **Este processo pode levar algum tempo, algo em torno de 15 a 30 minutos.**

```bash
eksctl create cluster -f cluster.yaml
```

Ao final desta etapa, o cluster deve estar disponível com seus nodes no status `Ready`. Use o comando `kubectl get nodes` para verificar o estado dos nodes.

```bash
kubectl get nodes
NAME                           STATUS   ROLES    AGE     VERSION
ip-10-11-1-91.ec2.internal     Ready    <none>   18h     v1.35.2-eks-f69f56f
ip-10-11-37-155.ec2.internal   Ready    <none>   7h59m   v1.35.2-eks-f69f56f
```

Verifique também se todos os pods do cluster estão com o status `Running`.

```bash
$ kubectl get pods -A
NAMESPACE     NAME                            READY   STATUS    RESTARTS   AGE
kube-system   aws-node-rs4lp                  2/2     Running   0          5h16m
kube-system   coredns-cd49f47f8-jh9pj         1/1     Running   0          5h19m
kube-system   coredns-cd49f47f8-mfpcx         1/1     Running   0          5h19m
kube-system   kube-proxy-52gpr                1/1     Running   0          5h16m
kube-system   metrics-server-99c97556-7t6dc   1/1     Running   0          5h14m
kube-system   metrics-server-99c97556-lzrpw   1/1     Running   0          5h14m
```

<BR>

### 3. Política de acesso

Após a criação do cluster, é importante criar uma política de acesso e um papel de serviço específico para que os pods do cluster se comuniquem com alguns serviços. Para isso, foi criado um pequeno script (`create_serv_role.sh`) que registra uma política e uma _role_ de serviço na AWS para esses pods. O script utiliza o arquivo de variáveis `.env` no mesmo diretório, para definir o nome da política e dos papéis. Caso queira, altere os valores neste arquivo.

```bash
./create_serv_role.sh
```

<BR>

### 4. Banco de dados

Três tabelas de um banco de dados relacional (_PostgreSQL_) são necessárias para os microserviços `auth`, `flag` e `targeting`. Neste caso, não há necessidade de 3 instâncias RDS; uma é o suficiente e menos onerosa.

> ⚠️ **Neste passo, pode ser mais interessante [criar a instância RDS pela console Web da AWS][criarrds], pois todos os parâmetros necessários são configurados de forma unificada, incluindo grupo de subnets e security-groups. Siga as recomendações abaixo.**

- **4.1** Para este laboratório, recomenda-se utilizar um tipo de instância de baixa capacidade, como a `db.t3.micro`.
- **4.2** **Não é** necessário muito espaço de armazenamento; o mínimo de 20GB já é o suficiente. O "autoscaling" também **não é** necessário.
- **4.3** É importante **associar a instância RDS à VPC do cluster EKS** e às suas sub-redes.
- **4.4** O acesso público **não é** necessário.
- **4.5** Desabilite o "Performance Insights" neste laboratório para reduzir o custo da instância.
- **4.6** Crie o database inicial com um nome específico (_sugestão `toggle_db`_).
- **4.7** O backup automático foi desabilitado neste teste a fim de reduzir o custo da instância.
- **4.8** Configure a conexão da instância RDS com as instâncias EC2.
- **4.9** Após criar a instância, aguarde até que ela esteja com o status `Available`. Em seguida, configure a URL de conexão no arquivo `010-secrets-db.yaml`, conforme abaixo.

```bash
# Inclua os dados da instância RDS nestas variáveis
DB_NAME="toggle_db"
DB_USER="toggle"
DB_PASS="toggle_dbmaster"

# Capturar a URL da instância RDS
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_NAME" \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

# URL codificada em Base64 da instância RDS com o schema postgres://
PSQL_URL_B64=$(echo -n "postgres://${DB_USER}:${DB_PASS}@${RDS_ENDPOINT}:5432/${DB_NAME}" | base64 -w 0)

sed -i "s@\s\sDATABASE_URL: .*@  DATABASE_URL: $PSQL_URL_B64@" manifest/010-secrets-db.yaml
```

- ⚠️ **4.10** Também é necessário inicializar as tabelas dos microserviços. Para isso, uma forma segura e fácil de acessar a instância é por meio do CloudShell na própria console da AWS. Ele já possui um cliente PostgreSQL e conectividade com a instância. As instruções de conexão estão disponíveis nos detalhes da instância RDS criada.
- ⚠️ **4.11** Após se conectar à instância RDS, copie os scripts SQL de inicialização das tabelas dos microserviços e execute seus comandos diretamente no terminal do PostgreSQL.

<BR>

### 5. Elasticach

O microserviço `evaluation-service` utiliza um cache para otimizar as requisições dos usuários finais. Para isso, é utilizado o Valkey Cache da AWS (_sugestão `fiap-toggle-valkey-cache`_).

> ⚠️ **Neste passo, pode ser mais interessante [criar a instância Elasticache pela console Web da AWS][elasticache] pois todos os parâmetros necessários são configurados de forma unificada, incluindo a VPC do cluster EKS e suas subnets.**

- **5.1** Utilize a configuração personalizada (_Customize default settings_).
- **5.2** Utilize a mesma VPC do cluster EKS.
- **5.3** Selecione as Availability Zones **privadas** do cluster.
- **5.4** Não há necessidade de backups automáticos neste ambiente de teste.
- **5.5** Não se esqueça de conectar a instância Valkey à instância EC2 do cluster EKS.

> **É necessário aguardar um tempo para que o "endpoint" do Valkey cache esteja disponível.**

```bash
########
# Aguarde o Valkey cache ficar disponível
########
# Capturar o endpoint do Valkey cache
CACHE_NAME="fiap-toggle-valkey-cache"
CACHE_ENDPOINT=$(aws elasticache describe-serverless-caches \
    --serverless-cache-name "$CACHE_NAME" \
    --query 'ServerlessCaches[0].Endpoint.Address' \
    --output text)

# Salvando a URL do endpoint no manifesto secrets do evaluation-service
sed -i "s@\s\sREDIS_URL: .*@  REDIS_URL: $(echo -n "rediss://${CACHE_ENDPOINT}:6379" | base64 -w 0)@" manifest/060-evaluation-service/062-secrets.yaml
```

<BR>

### 5. Nginx Ingress Controller

Para instalar o [Nginx Ingress Controller][nginx], basta carregar o seu manifesto padrão.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/cloud/deploy.yaml
```

<BR>

### 5. Escalonamento

- **5.1** O KEDA é utilizado  para escalonar o microserviço `analytics-service`, de modo que seus pods aumentem caso o tamanho da fila SQS aumente significativamente. O manifesto `073-scaledobject.yaml` define que os pods são escalados de acordo com o tamanho da fila SQS. Dessa forma, o `analytics-service` pode processar a fila mais rapidamente.

Para instalar o KEDA, basta aplicar seu manifesto, conforme [indicado em sua documentação][kedainstall].

```bash
kubectl apply --server-side -f https://github.com/kedacore/keda/releases/download/v2.19.0/keda-2.19.0.yaml
```

<BR>

### 6. Inicializar o ToggleMaster

Após a preparação do ambiente na AWS, os microserviços da ToggleMaster podem ser inicializados. Primeiro, porém, é necessário definir uma chave "mestre" para o serviço de autenticação. **Use um valor seguro.**

```bash
# Defina a chave de autenticação aqui
MASTER_KEY="admin123"

# Codificar a chave em base64 e salvar no secrets do auth-service
sed -i "s@\s\MASTER_KEY: .*@  MASTER_KEY: $(echo -n "$MASTER_KEY" | base64 -w 0)@" manifest/030-auth-service/032-secrets.yaml
```

Se tudo ocorreu bem até aqui, basta inicializar os microserviços com o comando `kubectl apply` apontando para os seus manifestos.

```bash
kubectl apply -R -f manifest/
```

<BR>

### 7. Validação

Nesta etapa, o sistema ToggleMaster deve estar ativo e pronto para receber mensagens. Para validar seu funcionamento, é necessário criar uma chave de autenticação com o microserviço `auth-service`, uma "feature flag" com o microserviço `flag-service` e uma regra de segmentação com o microserviço `targeting-service`.

- **4.1** Consulte os IPs dos serviços no cluster com o comando `kubectl`. O resultado deve ser algo similar a seguir.

```bash
$ kubectl get service -n toggle
NAME         TYPE           CLUSTER-IP       EXTERNAL-IP                              PORT(S)          AGE
analytics    ClusterIP      172.20.224.83    <none>                                   8005/TCP         108s
auth         ClusterIP      172.20.214.197   <none>                                   8001/TCP         5m23s
evaluation   LoadBalancer   172.20.111.225   abc123-123.us-east-1.elb.amazonaws.com   8004:32624/TCP   3m14s
flag         ClusterIP      172.20.12.175    <none>                                   8002/TCP         4m51s
targeting    ClusterIP      172.20.54.173    <none>                                   8003/TCP         3m57s
```

> ⚠️ **Utilize os IPs de cada microserviço nos comandos a seguir.**
> ⚠️ **Utilize a "master" key de microserviço de autenticação.**

- **4.2** Crie a flag e sua regra de segmentação com os comandos a seguir.

```bash
MASTER_KEY="admin123"
# Criar chave de autenticação
FLAG_TOKEN=$(curl -X POST http://172.20.214.197:8001/admin/keys \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $MASTER_KEY" \
    -d '{"name": "toggle-flag"}' | sed -n 's/.*"key":"\([^"]*\)".*/\1/p')

# Criar feature flag com a chave 
curl -X POST http://172.20.12.175:8002/flags \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $FLAG_TOKEN" \
    -d '{
            "name": "enable-feature",
            "description": "Ativa o novo recurso para os usuários",
            "is_enabled": true
        }'

# Criar uma regra de segmentação
curl -X POST http://172.20.54.173:8003/rules \
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

- **4.2** Envie mensagens para o ToggleMaster. Neste teste, são enviadas **1.000** mensagens, as quais são enfileiradas no SQS. O `analytics-service` processa as mensagens e as envia para a tabela do DynamoDB. Nesse momento, é possível observar tanto o enfileiramento de mensagens no SQS quanto sua gravação no DynamoDB. Utilize o console da AWS para observar isso.

    > ⚠️ **Este teste envia muitas mensagens ao ToggleMaster e pode levar um tempo, pois o serviço precisa se comunicar com a AWS. Se preferir, basta reduzir o número de mensagens enviadas para acelerar o processo.**

```bash
for i in $(seq 1000); do { curl "http://abc123-123.us-east-1.elb.amazonaws.com:8004/evaluate?user_id=teste-$i&flag_name=enable-feature" ; } done
```

- Opcionalmente, é possível observar as mensagens sendo processadas no log do `analytics-service`, o que pode levar um tempo.

[awscli]: https://aws.amazon.com/cli/
[kuberepo]: https://kubernetes.io/docs/tasks/tools/
[ambientelocal]: /local/
[criarsqs]: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/creating-sqs-standard-queues.html
[analyticsserv]: https://github.com/FIAP-TCs/analytics-service
[criarrds]: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_CreateDBInstance.html
[authserv]: https://github.com/FIAP-TCs/auth-service
[acessoec2]: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect.html
[home]: /
[nginx]: https://kubernetes.github.io/ingress-nginx/
[elasticache]: https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/set-up.html
[kedainstall]: https://keda.sh/docs/2.19/deploy/#yaml