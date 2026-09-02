# Aula 03 — Terraform + IAM | Hector Marcelo Pedroso dos Santos (RA: 6125136)

## Design da Estrutura IAM

A separação começou por uma pergunta simples: quem precisa **ler** e quem precisa **operar**?

O group `6125136-technova-developers` reúne quem só consome dados — desenvolvedor que precisa baixar um arquivo de bucket para depurar algo não precisa ligar máquina nem apagar nada. Já o `6125136-technova-platform-eng` é de quem mantém a infraestrutura de pé, então recebe EC2 e escrita no S3.

Anexei as policies aos **groups**, não aos usuários. Se amanhã entrar mais um dev, ele herda tudo ao ser incluído no group — não preciso lembrar quais policies anexar um a um, que é justamente onde erro humano acontece.

O caso do Rafael foi o mais interessante de resolver. Ele está nos dois groups, e o `deny-destructive` do developers vale para ele também. Resultado: o Rafael liga e desliga instâncias do projeto, mas **não consegue terminá-las**. Isso não é efeito colateral, é o comportamento desejado — destruir recurso deve exigir escalada deliberada de privilégio, não ser algo que se faz por engano numa terça à noite.

O Lucas é estagiário e está no group developers, o que lhe daria a mesma leitura da Juliana. Como a especificação pede "somente leitura", criei uma quarta policy (`intern-readonly`) anexada **diretamente ao user**, negando qualquer escrita. Sem ela, "estagiário" e "desenvolvedora plena" teriam exatamente o mesmo poder.

### As policies

| Policy | O que permite | Por quê |
|---|---|---|
| `s3-read` | `s3:GetObject`, `s3:ListBucket` em `technova-*` | Duas actions, não `s3:*`. Ler é ler. |
| `ec2-s3-full` | EC2 Describe + Start/Stop com Condition por tag + S3 read/write | Start/Stop só em instâncias com `Project=TechNova` |
| `deny-destructive` | Deny em `Delete*`, `Terminate*` | Rede de segurança: Deny vence qualquer Allow |
| `intern-readonly` | Deny em escrita, anexada ao user | Diferencia o estagiário dentro do mesmo group |
| `ec2-app-data` | Read/Write em `technova-app-data-*` | Permissão da aplicação, não de pessoa |

## Princípio do Menor Privilégio

O princípio é dar a cada identidade exatamente as permissões necessárias para o trabalho dela, e nada além. Não é desconfiança — é reduzir o tamanho do estrago quando algo der errado, seja por engano ou por credencial vazada.

**Exemplo 1 — escopo por recurso.** A policy `s3-read` não usa `Resource = "*"`. Ela aponta para `arn:aws:s3:::technova-*` e `arn:aws:s3:::technova-*/*`. Se a conta tiver um bucket de outro projeto, os devs da TechNova simplesmente não o enxergam.

**Exemplo 2 — Condition por tag.** Em `ec2-s3-full`, o Start/Stop tem `StringEquals` em `ec2:ResourceTag/Project = TechNova`. O engenheiro de plataforma tem poder real sobre EC2, mas só sobre as instâncias do projeto dele. A frota do resto da conta continua fora de alcance, mesmo que a action seja permitida.

**E se eu usasse `AmazonS3FullAccess`?**

Trocaria duas actions por mais de cem, e um escopo de `technova-*` por todos os buckets da conta. Na prática, dar `AmazonS3FullAccess` para o Lucas — estagiário — significaria que ele poderia apagar qualquer bucket de qualquer projeto no primeiro comando errado.

Nunca passei por um incidente assim nos meus projetos, mas trabalho como freelancer e a lógica é a mesma que já me faz pensar duas vezes antes de entregar acesso de administrador a um cliente: no momento em que a permissão é concedida, ela parece inofensiva; o problema aparece meses depois, quando ninguém lembra mais por que aquele acesso existe. Uma policy que declara exatamente `s3:GetObject` em `technova-*` continua explicando a si mesma daqui a um ano.

Vale notar que, mesmo se alguém anexasse `AmazonS3FullAccess` ao group developers por engano, a `deny-destructive` continuaria bloqueando as exclusões — porque Deny explícito prevalece sobre qualquer Allow, inclusive os das policies gerenciadas pela AWS. Foi para isso que ela existe.

## Diagrama de Permissões

```
FLUXO DE PESSOAS
================

  6125136-juliana-dev ──────┐
                            │
  6125136-lucas-intern ─────┼──► [ group: technova-developers ]
                            │              │
  6125136-rafael-platform ──┤              ├──► s3-read ────────► S3: technova-* (GetObject, ListBucket)
                            │              │
                            │              └──► deny-destructive ──► DENY Delete*/Terminate* (tudo)
                            │
                            └──► [ group: technova-platform-eng ]
                                           │
                                           └──► ec2-s3-full ──┬──► EC2 Describe (todas)
                                                              ├──► EC2 Start/Stop (só tag Project=TechNova)
                                                              └──► S3: technova-* (Get/Put)

  6125136-lucas-intern ─────────► intern-readonly ──► DENY toda escrita (anexada direto ao user)


FLUXO DA APLICAÇÃO
==================

  [ EC2 instance ]
         │
         │ usa
         ▼
  [ instance profile: 6125136-technova-ec2-profile ]
         │
         │ carrega
         ▼
  [ role: 6125136-technova-ec2-role ]
         │
         ├── trust policy: Principal = ec2.amazonaws.com (sts:AssumeRole)
         │
         └── permissions: ec2-app-data ──► S3: technova-app-data-* (Get/Put/List)
```

Repare que a role tem escopo **mais estreito** que o dos usuários: `technova-app-data-*` em vez de `technova-*`. A aplicação acessa menos que as pessoas, porque ela só precisa dos próprios dados — pessoas às vezes precisam investigar coisas, código não.

## Comandos Utilizados

```bash
terraform init
terraform fmt
terraform validate
terraform plan -no-color | tee terraform-plan-output.txt
terraform apply
terraform destroy
```

### Observação sobre a execução no AWS Academy

O `terraform plan` roda com sucesso e planeja os 20 recursos (evidência em `terraform-plan-output.txt`), mas o `terraform apply` falha no AWS Academy Learner Lab. A role `voclabs`, que o Learner Lab atribui ao aluno, não possui permissões de escrita em IAM:

```
AccessDenied: User: arn:aws:sts::210645360611:assumed-role/voclabs/...
is not authorized to perform: iam:CreateGroup
is not authorized to perform: iam:CreateUser
is not authorized to perform: iam:CreateRole
is not authorized to perform: iam:TagPolicy
```

O erro completo está em `evidencia-apply-accessdenied.txt`. Como nenhum recurso chegou a ser criado, não houve necessidade de `terraform destroy` — o `terraform state list` retorna apenas os `data sources`, sem recursos gerenciados.

Vale registrar que o próprio erro é uma demonstração prática do tema da aula: a sandbox aplica menor privilégio sobre mim. A `voclabs` me permite ler IAM (por isso o plan funciona) mas não escrever, exatamente como a `s3-read` permite ao dev baixar objetos mas não apagá-los.

## Reflexão

Console e Terraform chegam ao mesmo lugar, mas só um deles deixa rastro.

O que mais pesa para mim é **conseguir refazer tudo do zero**. Uma estrutura IAM criada no console existe só ali: se a conta for perdida, se for preciso replicar o ambiente em outra região, ou se alguém alterar uma policy e ninguém souber qual era o estado anterior, não há de onde partir — a única fonte da verdade é a tela do console naquele instante. Com Terraform, o `main.tf` é a fonte da verdade.

Isso vale dobrado para permissão, que é o tipo de coisa que se acumula silenciosamente. No console, alguém dá um acesso "temporário" numa sexta-feira e ele fica lá para sempre, porque não há registro de que ele deveria sair. Em código, esse acesso é uma linha num arquivo versionado: aparece no `git log`, tem autor, tem data, tem mensagem de commit, e sai por um `git revert` em vez de por memória.

Para uma equipe, a diferença fica ainda mais clara na revisão. No console, a permissão já está valendo quando alguém percebe. Em Terraform, o `terraform plan` mostra o efeito antes de aplicar, e um Pull Request coloca outra pessoa olhando a mudança antes que ela exista de verdade. É a diferença entre auditar depois do fato e revisar antes dele.

Para mim, que trabalho sozinho na maior parte dos projetos, o ganho imediato é outro: eu não preciso lembrar do que fiz. O código lembra por mim.
