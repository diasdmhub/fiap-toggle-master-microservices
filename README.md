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

> **ℹ️ Apesar da primeira implementação ser local, ela também utiliza os recursos SQS e DynamoDB da AWS pois os códigos originais não foram preparados para outras opções.**

- ↗️ [**Ambiente local**][ambientelocal]
- ↗️ [**Ambiente Kubernetes**][ambientekube]

<BR>

## 🗒️ Observações

[sistoggle]: https://github.com/FIAP-TCs
[fase1]: https://github.com/diasdmhub/fiap-toggle-master-monolith
[authserv]: https://github.com/FIAP-TCs/auth-service
[flagserv]: https://github.com/FIAP-TCs/flag-service
[targetserv]: https://github.com/FIAP-TCs/targeting-service
[evalserv]: https://github.com/FIAP-TCs/evaluation-service
[analyticserv]: https://github.com/FIAP-TCs/analytics-service
[ambientelocal]: ./togglelocal
[ambientekube]: ./togglekube