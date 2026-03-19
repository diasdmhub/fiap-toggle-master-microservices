# Tech Challenge Fase 2 - Microserviços "ToggleMaster"

> **Análise geral e implementação do "desafio" da Fase 2 do curso DevOps e Arquitetura Cloud da FIAP.**

Este projeto propõe a criação de um ambiente distribuído em "cloud", focado na AWS, para a execução dos microserviços do [sistema ToggleMaster][sistoggle] ([_o mesmo da Fase 1_][fase1]).

Nesta fase, a aplicação foi segregada em cinco microsserviços. Eles serão compartimentalizados e provisionados em uma infraestrutura em "cloud" da AWS, com orquestração e escalonamento por meio do Kubernetes (EKS).

<BR>

## 🏛️ Arquitetura

A arquitetura do ToggleMaster foi segmentada nos seguintes 5 microsserviços, cada um com seu respectivo repositório original:

- [↗️ auth-service][authserv]

    > (_Go_) Gerencia chaves de API e autenticação. (_Banco de Dados: PostgreSQL_)

- [↗️ flag-service][flagserv]

    > (_Python_) CRUD das definições das feature flags. (_Banco de Dados: PostgreSQL_)

- [↗️ targeting-service][targetserv]

    > (_Python_) Gerencia regras complexas de segmentação. (_Banco de Dados: PostgreSQL_)

- [↗️ evaluation-service][evalserv]

    > (_Go_) O "caminho quente" (hot path) de alta performance que retorna a decisão final (_true/false_). (_Cache: Redis_)

- [↗️ analytics-service][analyticserv]

    > (_Python_) Consome eventos de uma fila e salva dados de análise. (_Fila: AWS SQS, Banco de Dados: AWS DynamoDB_)

<BR>

## 🛠️ Implantação

Duas formas de implementação são apresentadas, uma em ambiente local com a utilização de gerenciadores de containers como o Docker ou Podman, e outra em ambiente "cloud", com o AWS EKS.

- ↗️ [**Ambiente local**][ambientelocal]
- ↗️ [**Ambiente Kubernetes**][ambientekube]

<BR>

## 🗒️ Observações

### Repositórios originais

Os repositórios originais apresentaram algumas inconsistências de versão ou dependências nas aplicações principais. Isso pode tornar o Tech-challenge mais moroso que o necessário e, fatalmente, inviabilizar a construção do desafio da Fase 2, pois traz uma carga desnecessária de troubleshooting e está fora de contexto com a disciplina.

Todas as inconsistências observadas foram registradas nos respectivos repositórios ([auth][authissue], [flag][flagissue], [target][targetissue] e [evaluation][evalissue]).

Os repositórios originais foram integrados a este com as correções necessárias para manter a consistência na reprodução dos testes em caso de alterações futuras.

<BR>

#### Instâncias RDS

O roteiro do desafio pede a criação de três instâncias de forma independente. Diante disso, surge a dúvida sobre a necessidade de se criar 3 "instâncias independentes" RDS PostgreSQL na AWS.

De acordo com os testes locais, as 3 bases de dados da aplicação podem ser executadas diretamente em uma única instância, desde que as tabelas sejam criadas corretamente.

A separação dessas instâncias pode ser vantajosa em termos de modularização do ambiente e, talvez, de sua manutenção. Por outro lado, unificar essas bases pode trazer mais economia para o ambiente, pois uma única instância tem um custo menor.

Além disso, o ambiente gratuito de laboratório da AWS não permite a criação de mais do que 2 instâncias RDS. Por esse motivo, não foi possível criar essas 3 instâncias RDS PostgreSQL.

Esses são pontos relevantes de discussão para se obter um bom custo-benefício, principalmente quando se trata de ambientes de produção.

<BR>

### Uso do SQS

Os repositórios da aplicação sugerem o uso do SQS para os testes em ambientes de laboratório. Além disso, os próprios microserviços do sistema ToggleMaster foram preparados para o SQS. No entanto, considerando o ambiente local, os microserviços poderiam ser um pouco mais flexíveis em relação à ferramenta de mensageria utilizada. Poderiam utilizar outra ferramenta para o enfileiramento como o RabbitMQ, Apache Pulsar, ActiveMQ, entre outras. Isso também pode ajudar a reduzir os custos.

<BR>

### Uso do DynamoDB

Quanto ao uso do DynamoDB, a própria AWS fornece uma versão do DynamoDB para uso local, o ["Dyanamodb-local"][dynamolocal]. Ela está disponível, inclusive, no Docker Hub como uma imagem de contêiner. Entretanto, o serviço `analytics-service` não foi preparado para essa opção.

O uso do DynamoDB-local é recomendado para testes e desenvolvimento, e ele pode se encaixar muito bem no ambiente de testes da ToggleMaster, desde que a aplicação esteja preparada para isso.

Outras opções que poderiam atender à necessidade de databases de chave-valor são sistemas como Valkey, Apache Cassandra, CouchDB, etc.

<BR>

### Observação quanto ao NGINX Ingress Controller

O roteiro do Tech-challenge nos instrui a instalar o [NGINX Ingress Controller][nginx], no entanto, esse recurso "ingress" possui uma programação para o seu fim de vida, e está com a manutenção reduzida (_best-effort_). Além disso, a própria Linux Foundation do Kubernetes sugere o uso do Gateway API, que é uma nova geração de APIs de Ingress, Load Balancing e Service Mesh.

<BR>

### Conclusão

Diante de tudo isso, eu ressalto essas questões, pois entendo que uma preparação diferente desse sistema de microserviços pode talvez:

- Trazer mais facilidade na migração de cloud providers, se necessário;
- Evitar um "vendor lock-in", ou seja, evitar ficar preso a somente uma ferramenta ou fornecedor;
- Reduzir gastos com o ambiente.

[sistoggle]: https://github.com/FIAP-TCs
[fase1]: https://github.com/diasdmhub/fiap-toggle-master-monolith
[authserv]: https://github.com/FIAP-TCs/auth-service
[flagserv]: https://github.com/FIAP-TCs/flag-service
[targetserv]: https://github.com/FIAP-TCs/targeting-service
[evalserv]: https://github.com/FIAP-TCs/evaluation-service
[analyticserv]: https://github.com/FIAP-TCs/analytics-service
[ambientelocal]: ./togglelocal
[ambientekube]: ./togglekube
[dynamolocal]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html
[nginx]: https://kubernetes.github.io/ingress-nginx/
[authissue]: https://github.com/FIAP-TCs/auth-service/issues/2
[flagissue]: https://github.com/FIAP-TCs/flag-service/issues/1
[targetissue]: https://github.com/FIAP-TCs/targeting-service/issues/1
[evalissue]: https://github.com/FIAP-TCs/evaluation-service/issues/1