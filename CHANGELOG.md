# Changelog

Todas as mudanças visíveis ao usuário são registradas aqui. O número da
versão segue **SemVer** (`MAJOR.MINOR.PATCH`) e é exibido na tela inicial
do app, abaixo da frase "App offline. Sem login. Sem necessidade de
internet."

> **Para sessões futuras do Claude Code (instruções obrigatórias):**
> Antes de fazer qualquer ajuste no projeto:
> 1. Leia o topo deste arquivo para saber a versão atual.
> 2. Leia o `lib/constants/app_version.dart` para confirmar.
> 3. Decida o bump de versão pelo tipo de mudança:
>    - **PATCH** (`X.Y.Z` → `X.Y.Z+1`): correção de bug, ajuste de texto,
>      melhoria visual pontual.
>    - **MINOR** (`X.Y.Z` → `X.Y+1.0`): novo recurso, nova tela, nova
>      regra de negócio.
>    - **MAJOR** (`X.Y.Z` → `X+1.0.0`): mudança que quebra dados antigos
>      ou redesenha o fluxo principal.
> 4. Atualize `kAppVersion` em `lib/constants/app_version.dart`.
> 5. Adicione a nova entrada no topo deste arquivo (abaixo do bloco de
>    instruções), com a data no formato `YYYY-MM-DD` e uma lista curta
>    dos ajustes.
> 6. Faça o ajuste pedido pelo usuário.

---

## 0.3.0 — 2026-05-26

- **Refresh visual estilo SaaS premium.** Paleta institucional CBBC
  mantida (azul cobalto + laranja), mas com fundo Slate 50, cards
  brancos com sombra suave, inputs arredondados e borda discreta.
- Home: botão de carregar arquivo virou cartão tapável com ícone de
  nuvem em destaque; modelos de planilha agrupados em um único card
  "Modelos de referência" com botões lado a lado; ícone discreto na
  frase "App offline".
- Resumo da importação: cabeçalho com badges separados de Clubes e
  Atletas, status de sucesso/erro com fundo pastel próprio, blocos de
  avisos/erros com faixa lateral colorida (vermelho/laranja).
- Configuração da partida: cada equipe envolvida em card próprio com
  título e barra azul à esquerda; bonificações agora usam interruptores
  (`SwitchListTile`) em vez de checkboxes; campos de formulário herdam
  o novo estilo Slate dos inputs.
- Quadra: soma de pontos de classificação fica em destaque (fonte 26pt
  em negrito, números com largura tabular para não "saltar"); quando o
  limite é excedido a célula ganha um glow vermelho animado; quadra
  com moldura refinada e sombra suave; atleta selecionado tem barra
  lateral azul + fundo azul translúcido com transição animada; botões
  operacionais ganharam ícones padronizados e altura mínima maior em
  celulares (acessibilidade); dropdown de pontuação máxima saiu do
  cabeçalho e virou ícone de ajustes no `AppBar`, liberando espaço
  vertical para a quadra.
- Templates `.xlsx`: colunas agora abrem com largura suficiente para o
  conteúdo (sem precisar puxar manualmente coluna por coluna).

## 0.2.0 — 2026-05-26

- Templates `.xlsx` agora usam dados anônimos (`Equipe A/B/...`,
  `Atleta 1/2/...`) e incluem célula para data de término da competição.
- Regra de bonificação sub-16/sub-23 considera a data de término da
  competição: vale o limite até o atleta completar 17/24 anos.
- Indicador de bonificação (estrelinha laranja) ao lado do nome do
  atleta bonificado em quadra e na lista de atletas.
- Tela de resumo da importação: edição em linha única (camisa, nome,
  data de nascimento, gênero, classe), exclusão de atleta (com
  confirmação), edição do nome da equipe (ícone de lápis) e exclusão
  da equipe inteira (ícone de lixeira).
- Tela de configuração da partida: seletor de cor da camiseta para
  cada equipe (5 cores escuras), tooltips explicativos nas opções de
  bonificação, exibição/edição da data de hoje e da data de término da
  competição. Removido o texto "Hard cap = 15".
- Tela de jogo: removidos os rótulos duplicados "Equipe A/B" sobre o
  placar; dica dentro da quadra passa a usar o nome do clube
  selecionado; cor da camiseta vinda do setup é refletida nos chips e
  ícones.
- Botões operacionais (limpar Equipe A/B, trocar equipes, etc.)
  diminuem em telas estreitas (< 720 px) para não atrapalhar a lista
  de atletas.
- AppBar com logo CBBC à esquerda do título (em vez de empilhado),
  ligeiramente maior e mais legível.
- Suporte a rotação automática (retrato e paisagem).
- Ícone do app passa a usar a logotipo CBBC azul transparente em vez
  do ícone padrão do Flutter.
- Arquivo `CHANGELOG.md` + `lib/constants/app_version.dart` para
  rastrear versões a cada rodada de ajustes.

## 0.1.0 — primeira release CBBC

- Fork inicial do IWBF Team Points Control adaptado para CBBC
  (português, clube no lugar de país, mixed gender permitido).
- Parsers de planilha `.xlsx` e PDF.
- Tela de quadra ao vivo com controle de pontos e bonificação.
