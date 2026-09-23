# AWS VPC Terraform Module

Módulo Terraform reutilizável para criação de uma **AWS VPC IPv4** com suporte opcional a subnets públicas e conectividade com a internet.

O módulo foi desenhado para ser consumido por um repositório raiz de infraestrutura, como o `mmsorg-iac`, mantendo separadas as responsabilidades de:

- **módulo VPC:** implementação e abstração da topologia de rede;
- **repositório consumidor:** composição dos módulos e definição dos valores específicos de cada ambiente.

O módulo não conhece workloads específicos. EC2 Image Builder, ECS, EKS, RDS e outros consumidores devem apenas receber os outputs de rede de que necessitam.

## Arquitetura atual

Quando pelo menos uma subnet pública é informada, a topologia criada é:

```text
VPC
│
├── Internet Gateway
│
├── Public Route Table
│   └── 0.0.0.0/0 -> Internet Gateway
│
└── Public Subnet(s)
```

Quando `public_subnets = {}`, somente a VPC é criada.

Nesta versão o módulo não cria NAT Gateway, Elastic IP, VPC Endpoint, Transit Gateway, Network Firewall, subnets privadas ou Security Groups de workloads.

## Recursos criados

Dependendo dos inputs, o módulo pode criar:

- `aws_vpc`;
- `aws_internet_gateway`;
- `aws_subnet`;
- `aws_route_table`;
- `aws_route`;
- `aws_route_table_association`.

O Internet Gateway e os recursos de roteamento público são criados somente quando existem subnets públicas.

## Requisitos

| Requisito | Versão |
|---|---|
| Terraform | `>= 1.3.0` |
| AWS Provider | `>= 6.0.0` |

O módulo declara apenas os requisitos do provider. A configuração efetiva de região, credenciais, `assume_role`, profiles e demais opções deve permanecer no root module, por exemplo no `mmsorg-iac`.

## Como usar

Exemplo de consumo pelo `mmsorg-iac`:

```hcl
module "vpc" {
  source = "<vpc-module>"

  name            = "image-builder"
  ipv4_cidr_block = "10.10.0.0/16"

  public_subnets = {
    build = {
      ipv4_cidr_block         = "10.10.0.0/24"
      availability_zone       = "sa-east-1a"
      map_public_ip_on_launch = true
    }
  }

  tags = local.common_tags
}
```

O output pode então ser passado para outro módulo:

```hcl
module "ec2_image_builder" {
  source = "<ec2-image-builder-module>"

  subnet_id = module.vpc.public_subnet_ids["build"]

  # Demais configurações do workload.
}
```

O módulo VPC não deve referenciar diretamente o módulo de EC2 Image Builder.

## Criar somente a VPC

`public_subnets` é opcional. Portanto, o módulo também pode ser utilizado somente para criar a VPC:

```hcl
module "vpc" {
  source = "<vpc-module>"

  name            = "shared-services"
  ipv4_cidr_block = "10.20.0.0/16"

  tags = local.common_tags
}
```

Nesse cenário não serão criados Internet Gateway, route table pública, rota para internet ou subnets.

## Adicionar mais subnets públicas

As subnets são fornecidas através de um mapa. A chave representa a identidade estável da subnet no Terraform.

```hcl
public_subnets = {
  public_a = {
    ipv4_cidr_block   = "10.20.1.0/24"
    availability_zone = "sa-east-1a"
  }

  public_b = {
    ipv4_cidr_block   = "10.20.2.0/24"
    availability_zone = "sa-east-1b"
  }
}
```

O módulo utilizará internamente endereços Terraform como:

```text
aws_subnet.public["public_a"]
aws_subnet.public["public_b"]
```

E os outputs preservarão as mesmas chaves:

```hcl
module.vpc.public_subnet_ids["public_a"]
module.vpc.public_subnet_ids["public_b"]
```

Evite renomear uma chave existente sem necessidade, pois a identidade da instância Terraform também será alterada.

## Public IPv4

O atributo `map_public_ip_on_launch` possui default `false`:

```hcl
map_public_ip_on_launch = false
```

Ative-o somente quando o workload realmente precisar receber IPv4 público automaticamente:

```hcl
public_subnets = {
  build = {
    ipv4_cidr_block         = "10.10.0.0/24"
    availability_zone       = "sa-east-1a"
    map_public_ip_on_launch = true
  }
}
```

Uma subnet é considerada pública pelo seu roteamento para um Internet Gateway. O fato de ser pública não exige que todos os workloads recebam IPv4 público automaticamente.

## Inputs

| Nome | Descrição | Tipo | Default | Obrigatório |
|---|---|---|---|---|
| `name` | Nome base utilizado na identificação da VPC e dos recursos associados. | `string` | n/a | sim |
| `ipv4_cidr_block` | Bloco CIDR IPv4 da VPC. | `string` | n/a | sim |
| `public_subnets` | Mapa das subnets públicas que serão criadas. | `map(object(...))` | `{}` | não |
| `tags` | Tags aplicadas aos recursos criados pelo módulo. | `map(string)` | `{}` | não |

### Estrutura de `public_subnets`

```hcl
map(object({
  ipv4_cidr_block         = string
  availability_zone       = string
  map_public_ip_on_launch = optional(bool, false)
}))
```

| Atributo | Descrição | Obrigatório | Default |
|---|---|---|---|
| `ipv4_cidr_block` | CIDR IPv4 da subnet. | sim | n/a |
| `availability_zone` | Availability Zone onde a subnet será criada. | sim | n/a |
| `map_public_ip_on_launch` | Habilita atribuição automática de IPv4 público. | não | `false` |

Os CIDRs IPv4 aceitos pelo módulo devem possuir prefixo entre `/16` e `/28`.

O módulo valida formato, faixa de prefixo e duplicidade exata dos CIDRs informados. Relações como sobreposição entre subnets e pertencimento ao CIDR da VPC continuam sendo validadas pela AWS durante a criação dos recursos.

## Outputs

| Nome | Descrição |
|---|---|
| `vpc_id` | ID da VPC criada. |
| `vpc_ipv4_cidr_block` | CIDR IPv4 da VPC criada. |
| `public_subnet_ids` | Mapa de IDs das subnets públicas preservando as chaves informadas no input. |

Exemplo:

```hcl
public_subnet_ids = {
  build    = "subnet-0123456789abcdef0"
  public_b = "subnet-0123456789abcdef1"
}
```

## Tags e nomenclatura

O consumidor pode fornecer tags através de:

```hcl
tags = local.common_tags
```

O módulo combina essas tags com a tag `Name` definida internamente para cada recurso.

Exemplos de nomes gerados:

```text
<name>
<name>-igw
<name>-public-rt
<name>-<subnet-key>
```

Informações específicas de organização, ambiente, conta AWS ou aplicação não devem ser hardcoded dentro do módulo.

## Segurança

A responsabilidade deste módulo é a topologia de rede.

Security Groups específicos de workloads devem ser criados pelos módulos responsáveis por esses workloads ou por módulos dedicados a Security Groups.

O módulo não cria regras de entrada públicas e não deve assumir requisitos de segurança específicos de EC2 Image Builder, ECS, EKS ou qualquer outro consumidor.

## Custos

A arquitetura inicial evita componentes gerenciados que podem gerar custos contínuos sem necessidade.

Esta versão não cria:

- NAT Gateway;
- Elastic IP;
- VPC Interface Endpoint;
- PrivateLink;
- Transit Gateway;
- Network Firewall.

IPv4 público pode gerar cobrança e, por isso, `map_public_ip_on_launch` permanece desabilitado por padrão.

Recursos adicionais devem ser incluídos somente quando houver requisito concreto que justifique custo e complexidade adicionais.

# Como evoluir o módulo

A evolução deve preservar a responsabilidade do repositório: abstrair VPC e componentes diretamente relacionados à sua topologia, sem incorporar comportamento específico de workloads.

## Antes de adicionar uma nova variável

Avalie:

1. O consumidor realmente precisa controlar esse valor?
2. Existe um default seguro e previsível?
3. O valor representa configuração pública ou detalhe interno?
4. É provável que varie entre ambientes?
5. A variável mantém a interface simples?

Evite expor todos os argumentos disponíveis no provider AWS apenas porque eles existem.

## Antes de adicionar um novo recurso

Confirme que o recurso pertence à responsabilidade da VPC.

Exemplos que podem fazer sentido como evolução deste módulo:

- subnets privadas;
- suporte a IPv6;
- secondary CIDR blocks;
- VPC Flow Logs, caso sejam definidos como responsabilidade deste módulo.

Recursos que podem justificar módulos separados, dependendo da arquitetura:

- Security Groups;
- Transit Gateway;
- Network Firewall;
- VPNs complexas;
- componentes específicos de workloads.

A regra principal é evitar transformar `aws-module-vpc` em um módulo genérico de toda a rede AWS.

## Organização dos arquivos

Utilize a seguinte responsabilidade:

```text
main.tf       -> recursos AWS
variables.tf  -> interface pública de entrada
outputs.tf    -> contrato público de saída
locals.tf     -> nomes, tags, condições e transformações
versions.tf   -> requisitos Terraform e providers
README.md     -> documentação de uso e evolução
```

Crie arquivos adicionais somente quando eles melhorarem efetivamente a organização e a legibilidade.

Não crie `data.tf`, por exemplo, se nenhum data source for utilizado.

## Recursos opcionais

Para recursos que existem apenas quando uma funcionalidade está habilitada:

- prefira `count` para casos simples de ligado/desligado;
- prefira `for_each` quando os recursos possuírem identidade própria.

Exemplo atual:

```hcl
count = local.has_public_subnets ? 1 : 0
```

é adequado para o Internet Gateway, pois existe no máximo uma instância controlada por uma condição.

Para subnets:

```hcl
for_each = local.public_subnets
```

é preferível, pois cada subnet possui identidade própria.

## Novos outputs

Adicione um output somente quando outro módulo ou o root module realmente precisar consumir aquele valor.

Evite expor detalhes internos, como IDs de recursos utilizados apenas para implementar a própria VPC.

Por exemplo, atualmente não são expostos:

```text
internet_gateway_id
public_route_table_id
route_id
route_table_association_id
```

Isso permite alterar a implementação interna no futuro sem quebrar os consumidores.

## Compatibilidade e breaking changes

Considere como potencial breaking change:

- renomear uma variável existente;
- mudar o tipo de uma variável;
- alterar a semântica de um default;
- remover ou renomear outputs;
- alterar chaves que definem identidades utilizadas por `for_each`;
- mudar comportamento existente de forma incompatível.

Antes de uma alteração desse tipo, documente:

1. o que mudou;
2. por que a mudança é necessária;
3. qual impacto existe para os consumidores;
4. como realizar a migração.

Sempre que possível, prefira evoluções compatíveis.

## Provider AWS

Não configure o provider dentro deste módulo:

```hcl
# Não fazer dentro do módulo.
provider "aws" {
  region = "sa-east-1"
}
```

O root module é responsável pela configuração:

```hcl
provider "aws" {
  region = var.aws_region
}
```

O módulo deve apenas declarar a versão mínima compatível em `versions.tf`.

## Checklist para uma alteração

Antes de publicar uma alteração:

- [ ] A funcionalidade pertence ao escopo da VPC.
- [ ] Não há configuração específica de ambiente hardcoded.
- [ ] Não há referência direta a workloads consumidores.
- [ ] Novas variáveis possuem `description` e tipo explícito.
- [ ] Defaults são seguros e justificáveis.
- [ ] Validações foram adicionadas quando agregam valor sem duplicar excessivamente a AWS.
- [ ] `for_each` e `count` foram usados de acordo com a identidade dos recursos.
- [ ] Apenas outputs realmente necessários foram expostos.
- [ ] Tags seguem o padrão existente.
- [ ] O README foi atualizado.
- [ ] Possíveis breaking changes foram identificados.
- [ ] O código foi formatado com `terraform fmt`.
- [ ] `terraform init` e `terraform validate` foram executados com sucesso.

Quando disponível no pipeline ou ambiente de desenvolvimento, também é recomendado validar com ferramentas como TFLint, Checkov, tfsec ou Trivy.

## Princípios de evolução

Ao evoluir este módulo, priorize:

```text
clareza > abstração excessiva
padronização > soluções específicas
reutilização > duplicação
segurança > conveniência
manutenibilidade > complexidade
```
