# Controle de Classificação CBBC — contexto auto-carregado

> Lido automaticamente no início de cada sessão.

## O que é

Fork do IWBF Team Points Control adaptado para a CBBC (Confederação
Brasileira de Basquetebol em Cadeira de Rodas). UI 100% pt-BR.

## Convenções principais

- **Clube no lugar de país.** Sem bandeira, sem `CountryResolverService`.
  Campos do modelo são `clubName` e `fullName` (não `surname/firstName`).
- **Mixed gender é permitido.** Não há dialog/alerta de "gender
  mismatch". `Team` não carrega gênero.
- **Bonificação** vive em `BonusRules` (campo `_bonusRules` de
  `MatchState`). Quando há atleta qualificado em quadra, o
  `effectiveLimitTeamX` sobe para `kBonusPointCeiling = 15.0`.
- **Parsers**: `SpreadsheetParserService` (xlsx) e `PdfParserService`
  (PDF texto-extraível via `syncfusion_flutter_pdf`). Os dois usam
  `canonicalField` de `lib/services/column_mapping.dart` para
  mapear cabeçalhos pt-BR/EN → campo canônico.
- **Cores**: `CbbcColors` em `lib/theme/cbbc_theme.dart`. Azul cobalto
  primário, laranja basquete secundário.

## Build local / Codespaces

- `.devcontainer/post-create.sh` baixa Flutter 3.24.5 e roda
  `flutter create .` pra gerar arquivos Android/Web faltantes.
- Local: `flutter pub get && flutter analyze && flutter test &&
  flutter run -d web-server --web-port 8080`.

## CI

- Workflow `.github/workflows/build-apk.yml` roda em push pra main /
  feat/* / fix/*. Gera APK release não-assinado (keystore debug).

## Estado

- v0.1.0 — primeira release CBBC. Sem testes herdados do IWBF (deletados
  na migração — só `test/smoke_test.dart` valida render + bonus rules).
