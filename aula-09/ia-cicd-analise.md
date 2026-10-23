# Análise — Docker Registry e IA no CI/CD

**Aluno:** Hector Marcelo Pedroso dos Santos · **RA:** 6125136 · **Aula 09**

## 1. Por que o Amazon ECR

Escolhi o **ECR** porque o ambiente (AWS Academy Learner Lab) já é AWS: o login usa as mesmas credenciais do Lab (`aws ecr get-login-password`), sem criar conta ou token novo em outro serviço. O registry é **privado** por padrão, fica na mesma região (`us-east-1`) de onde a imagem será executada e não sofre o limite de pulls anônimos do Docker Hub.

O repositório foi criado com **scan on push** (varredura de vulnerabilidades a cada push) e recebeu uma **lifecycle policy**. O console mostrou 9 imagens para apenas 2 com tag: cada rebuild gera um digest novo e deixa o anterior sem tag, e isso acumula custo de armazenamento. A policy expira imagens **sem tag** com mais de 7 dias.

Contra: o ECR amarra o projeto à AWS, e o GHCR seria mais simples para um repositório que já vive no GitHub. Para este laboratório a integração com IAM pesou mais.

## 2. Estratégia de tags

O `ecr-push.sh` publica a mesma imagem com várias tags:

| Tag | Exemplo | Para quê |
|---|---|---|
| `sha-XXXXXXX` | `sha-d7ed469` | Rastreabilidade: liga a imagem ao commit exato |
| `latest` | `latest` | Conveniência; sempre a última publicada |
| semver completo | `1.0.0` | Versão de release, para rollback preciso |
| semver parcial | `1.0`, `1` | Quem aceita atualizações de patch ou minor |

As tags semver só são geradas quando o commit tem uma git tag `vX.Y.Z`.

Três observações vindas da prática:

- **Tag é ponteiro, digest é identidade.** O console do ECR mostra *Tag immutability: Mutable*, então `latest` pode ser reescrita. Ao rodar o script de novo sem mudar o código, o digest mudou, porque o build embute uma *attestation* com data. Para reprodutibilidade exata, o pull deveria ser por digest (`repo@sha256:...`).
- **Rollback validado:** `docker pull ...:1.0.0` retornou o digest esperado.
- **Uma imagem com várias tags é uma só imagem.** Isso importou na lifecycle policy (seção 5).

## 3. Padrões detectados pelo AI review

O script analisa **somente as linhas adicionadas** pelo PR, em arquivos JS/TS, e classifica por severidade:

| Severidade | Padrão |
|---|---|
| CRITICAL | secret hardcoded (senha, token, api key; nomes em inglês e pt-BR), chave de acesso AWS (`AKIA`/`ASIA`), chave privada, `eval()`, `new Function()`, SQL injection (SQL + concatenação ou interpolação) |
| WARNING | `console.log`/`console.debug`, `catch` vazio (uma linha ou várias), `debugger`, `innerHTML =`, `exec()` com valor dinâmico |
| INFO | `TODO`/`FIXME`/`HACK`, URL `http://` sem TLS |

São 13 regras. Nos achados de secret, o trecho aparece como `[redigido]`: o comentário público do PR não pode repetir o segredo que acabou de encontrar.

## 4. Lógica do review (e o "prompt")

Esta versão **não chama um modelo de linguagem**: é um analisador por regras (regex), determinístico, sem prompt. Foi uma escolha consciente: para padrões como `eval()` e segredos, regras são rápidas, gratuitas, reproduzíveis e não alucinam.

Fluxo:

1. O workflow roda em `pull_request` (`opened`, `synchronize`, `reopened`) e gera `git diff --unified=0 base...head`.
2. O `ai-review.js` lê o diff, guarda para cada linha adicionada o arquivo e o número da linha, e aplica as regras.
3. Monta uma tabela por severidade e publica como comentário. Um marcador invisível (`<!-- technova-ai-review -->`) permite **atualizar** o comentário existente em vez de criar outro a cada push.
4. Se houver algum CRITICAL, sai com `exit 1` e o check do PR fica vermelho (**quality gate**). WARNING e INFO não bloqueiam.

Se a revisão usasse um LLM, o prompt precisaria pedir saída estruturada (arquivo, linha, severidade, justificativa), receber só o diff, e ter o resultado validado por regras como estas antes de bloquear qualquer coisa.

## 5. Quando confiar na IA (e quando não)

**Confiar** em verificações objetivas e repetíveis: segredo no código, `eval()`, SQL montado por concatenação. O erro custa caro e o padrão é inequívoco.

**Desconfiar** quando o julgamento depende de contexto. Dois casos reais deste trabalho:

- **Falso negativo meu:** a primeira versão da regra de secret só conhecia nomes em inglês. No PR de teste, a variável `senhaAdmin = 'SenhaFake123'` **passou despercebida**. Só apareceu rodando contra código real; corrigi incluindo nomes em português e prefixos (`adminPassword`). Também tirei `auth` da lista, pois casaria com `author`.
- **A revisão de outra IA achou um erro meu.** O revisor automático (Codex) comentou que a regra de lifecycle `sha-*` poderia apagar imagens antigas **junto com as tags semver delas**, pois uma imagem tem várias tags e o ECR expira a imagem inteira. Eu tinha afirmado o contrário. Estava certo: removi essa regra e mantive só a de imagens sem tag.

Lição: use IA e automação como **segunda opinião**, não como autoridade, e sempre teste com casos reais (inclusive os que deveriam passar).

## 6. Limitações

- **Análise linha a linha:** um SQL montado em várias linhas, ou um segredo quebrado em partes, escapa.
- **Sem análise de fluxo de dados:** `eval(x)` é sempre CRITICAL, mesmo que `x` seja constante, e a injeção real via variável intermediária pode passar.
- **Dependência de nomes:** segredo em variável chamada `x` não é detectado.
- **Só JS/TS:** outras linguagens e arquivos de configuração (`.env`, YAML) não são analisados.
- **O gate vermelho não impede o merge sozinho:** no PR de teste o botão *Merge* continuou ativo. Para bloquear de verdade é preciso marcar o check como obrigatório na proteção de branch.
- **Segredo já commitado continua no histórico**: o gate avisa, mas a chave precisa ser revogada.
- **PRs de fork** recebem token somente leitura: o comentário pode falhar, mas o gate continua valendo (o script trata isso sem esconder o resultado).
- **Todo PR para `master` aciona também o CI da aula 08**, pois o workflow dela não filtra por pasta.

## Evidências

`screenshots/`: `ecr-console.png`, `ecr-push-ok.png`, `ecr-rollback-pull.png`, `ai-review-comment.png`, `quality-gate-block.png`, `actions-runs.png`, `codex-review-lifecycle.png` (revisão do Codex apontando o problema da lifecycle, hoje marcado como *Outdated* após a correção).
