# Phase 1 — Main contract (`contracts/SupplyChainDemo.sol`) — Plano Executivo

**Status**: Steps 1–5 ✅ concluídos; próximo: Step 6 (`confirmDelivery`). Interface refatorada (D5/D6/D7): `createBatch(batchId, receiver, carrier, auditor)`, `passCustody(batchId)`, auditor/carrier/receiver todos designados na criação.

## Decisões de design (fixadas)

1. **Herança**: `contract SupplyChainDemo is ISupplyChainDemo, AccessControl, Pausable, ReentrancyGuard`.
2. **Roles**: `MANUFACTURER_ROLE`, `AUDITOR_ROLE`, `CARRIER_ROLE`, `RECEIVER_ROLE` como `bytes32 public constant` (via `keccak256`).
3. **Autorização explícita**: `_requireRole(role)` helper privado, não `onlyRole` nativo (projeto exige `Unauthorized` customizado).
4. **Mapeamento ator → ação**: ver seção "Forma final" do plan completo.
5. **Constructor**: `constructor(address admin)` com validação `admin != address(0)`, usa `_grantRole` interno.
6. **Pausable**: `pause()`/`unpause()` com `onlyRole(DEFAULT_ADMIN_ROLE)`, `whenNotPaused` em todas as 6 funções de domínio.
7. **ReentrancyGuard**: `nonReentrant` nas 6 funções (defesa em profundidade).
8. **Existência**: `_batches[id].createdAt != 0`.
9. **Pré-block status**: `mapping(bytes32 => BatchStatus) private _preBlockStatus`.

## Prática de testes integrados

**A cada seção implementada**, antes de avançar:
1. Revisar quais testes se aplicam àquela seção
2. Escrever/atualizar testes em `contracts/SupplyChainDemo.t.sol` (Solidity/Forge) se necessário
3. Rodar `npm run test:sol` e validar que novos testes passam
4. Registrar no plano quais testes foram adicionados/revisados
5. Só depois avançar para a próxima seção

Isso sincroniza a implementação com a validação desde o início.

**Nota (Step 2) — testes de `createBatch` adiados para o Step 3:** decidimos NÃO escrever os testes de `createBatch` logo após implementá-lo, e sim adiá-los até depois de adicionar o controle de acesso (Step 3). Razão: sem roles, faltaria o caso `Unauthorized`, e a assinatura de comportamento da função muda quando as roles entram — testar agora significaria reescrever o teste em seguida (retrabalho). Regra geral derivada: quando uma seção introduz comportamento que uma seção seguinte iminente vai alterar, adiar o teste até a função atingir um estado "suficiente" (estável o bastante para não gerar retrabalho).

**Nota (Step 4) — RESTRIÇÃO do Solidity: contrato abstrato não deploya.** Um contrato que não implementa TODAS as funções da interface é `abstract` e não pode ser instanciado (`new SupplyChainDemo(...)`), logo não pode ser testado. `SupplyChainDemo` só fica concreto ao fim do Step 7 (todas as 6 funções de domínio implementadas). **Estratégia adotada**: escrever os testes de cada função IMEDIATAMENTE após implementá-la (memória fresca = teste preciso), mas RODAR toda a suíte de uma vez ao fim do Step 7, quando o contrato ficar concreto. Separar "escrever" (sem restrição) de "rodar" (exige concreto) preserva a precisão do teste-por-peça sem violar a regra do Solidity. O teste de `createBatch` já está escrito em `SupplyChainDemo.t.sol` (correto; ainda não roda).

## Checklist de execução (modo tutor — construção por seção)

- [x] 1. **Modelo de dados puro** — contrato vazio `is ISupplyChainDemo`, `mapping(bytes32 => Batch) private _batches`, `getBatch`/`hasBatch` (view).
- [x] 2. **Primeira ação: `createBatch`** — validar `receiver != 0`, checar duplicidade, gravar `Batch`, emitir evento. **+ D3: `BatchCreated` ganhou `receiver` indexed.**
- [x] 3. **Controle de acesso** — `AccessControl`, roles (4), constructor(admin), `_requireRole` helper, aplicado em `createBatch` (MANUFACTURER_ROLE). **+ D4: constructor recebe admin param.**
- [x] 4. **Guarda de status + `anchorAudit`** — helpers `_requireStatus`/`_requireExists`, `getBatch` refatorado p/ `_requireExists`, `anchorAudit` (AUDITOR_ROLE, guarda `Created`→`Audited`, evento `AuditAnchored`). Sem validação de `auditHash` zero (decisão). Bug pego na revisão: `BatchAudited`→`AuditAnchored`.
- [x] 5. **`passCustody`** — carrier designado na criação atesta aceitação (`msg.sender == batch.carrier`), `Audited → InTransit`. Dupla checagem role + identidade. Testes escritos (happy + 4 reverts). **Refatoração D5/D6/D7: handshake via designação na criação, auditor vinculado, param removido.**
- [ ] 6. **`confirmDelivery`** — com checagem de receiver match.
- [ ] 7. **`blockBatch` / `unblockBatch`** — mapping `_preBlockStatus`, regra "any except Blocked".
- [ ] 8. **Cross-cutting: `Pausable`** — adicionar herança, modifiers, `pause()`/`unpause()`.
- [ ] 9. **Cross-cutting: `ReentrancyGuard`** — adicionar herança, modifiers.
- [ ] 10. **Polimento: NatSpec completo** — `@title`/`@author`/`@notice`/`@dev`/`@param`/`@return`.
- [ ] 11. **Gerar audit** — `src/inspection/phase-1-audit.md` (inglês).
- [ ] 12. **Atualizar ROADMAP** — marca Phase 1 done, "Last updated", "Current state".
- [ ] 13. **Commit final** — fechamento da fase.

## Decisões registradas para auditoria final

**D1 — Storage `_batches` como `private` + getter customizado, não `public`:**
- Razão: A interface `ISupplyChainDemo` já declara a assinatura de `getBatch`. Embora o Solidity compilador gerasse automaticamente um getter se usássemos `mapping(bytes32 => Batch) public _batches`, a prática de encapsulamento (private + getter customizado) deixa aberto para validações futuras (ex: checagens de permissão, logging) sem quebrar a interface pública. Documentado aqui para evitar questões de auditores posteriores.

**D4 — Constructor recebe `admin` como parâmetro, não usa `msg.sender`:**
- Assinatura: `constructor(address admin)` — valida `admin != address(0)` (`InvalidAddress`) e concede `DEFAULT_ADMIN_ROLE` ao endereço passado via `_grantRole` interno.
- Razão: desacopla "quem faz o deploy" de "quem administra o contrato". Permite passar um endereço configurado (ex.: um multisig de governança) como admin no momento do deploy, em vez de forçar que o deployer (uma EOA qualquer, possivelmente descartável) seja o super-admin permanente. O módulo Hardhat Ignition da Phase 4 fornecerá esse endereço. Trade-off aceito: uma linha extra de validação e a responsabilidade de passar o endereço correto no deploy, em troca de flexibilidade e melhor postura de segurança (admin ≠ deployer).

**D3 — [DESCOBERTA DE IMPLEMENTAÇÃO] `BatchCreated` recebe `receiver` como 3º param indexed:**
- Assinatura antiga: `event BatchCreated(bytes32 indexed batchId, address indexed manufacturer)`.
- Assinatura nova: `event BatchCreated(bytes32 indexed batchId, address indexed manufacturer, address indexed receiver)`.
- Contexto: descoberto DURANTE a implementação da Phase 1 (não era design pré-definido; a interface fora declarada "settled" na Phase 0). Ao implementar `createBatch`, questionou-se criticamente a completude do evento.
- Razão: `BatchCreated` é o **único evento bipartite** do contrato — é a única operação que estabelece uma relação entre duas partes (manufacturer cria E designa o receiver na mesma tx), análogo a `Transfer(from, to, tokenId)` do ERC-721. Todos os outros eventos têm um único ator agindo sobre um batch existente. Incluir `receiver` indexed permite que um consumidor off-chain (dApp do receiver) filtre "quais lotes estão vindo para mim" direto dos logs, sem varrer todos os `BatchCreated` + chamar `getBatch` em cada. Precedente: `AuditAnchored` já carrega um 3º campo não-ator (`auditHash`), o dado crítico daquele evento; aqui o dado crítico é o destinatário.
- Viabilidade técnica: 3 params indexed é o máximo do Solidity (batchId + manufacturer + receiver = 3, cabe); custo ~375 gas/topic extra, desprezível.
- Impacto: alterada a interface `ISupplyChainDemo.sol` e a doc `CLAUDE.md`/`AGENTS.md`. Deve constar na auditoria final como acurácia de implementação.

**D7 — [DESCOBERTA DE IMPLEMENTAÇÃO] Auditor vinculado (designado na criação), fechando o gap de captura do `anchorAudit`:**
- Problema identificado: `anchorAudit` estava "aberto" — qualquer endereço com `AUDITOR_ROLE` podia ancorar em qualquer batch em `Created`. Como a transição é mão-única e terminal (não há re-auditoria), um auditor autorizado malicioso podia fazer front-run e ancorar um hash errado, travando o batch (griefing/DoS dentro da fronteira de confiança).
- Decisão: sob o bar de produção (ver [[production-grade-rigor]]), FECHAR o gap em vez de só documentar — vincular o auditor. O manufacturer designa o `auditor` no `createBatch` (junto de receiver e carrier); `anchorAudit` passa a exigir `msg.sender == batch.auditor` (além de `AUDITOR_ROLE` e status). Simétrico ao carrier/receiver: os três atores downstream são designados na criação e cada um age na sua vez, guardado por role + identidade + status.
- Coerência: fechar o gap do carrier e deixar o do auditor aberto seria inconsistente. Ambos têm o mesmo padrão estrutural; ambos são fechados por binding.
- Resíduo aceito (documentar, não é gap estrutural): o auditor DESIGNADO, se malicioso, ainda pode ancorar hash errado — confiança irredutível na parte contratada, com accountability on-chain (identidade registrada). Diferente do gap de captura por qualquer role-holder, este não tem fix limpo.
- Impacto na interface: `createBatch(bytes32, address receiver, address carrier, address auditor)`; `BatchCreated` ganha `auditor` como dado não-indexed (auditor já é indexed no `AuditAnchored`, seu evento de ação); `anchorAudit` ganha o check de identidade e para de gravar `batch.auditor`.

**D5 — [DESCOBERTA DE IMPLEMENTAÇÃO] Handshake bilateral de custódia via designação na criação:**
- Contexto: ao implementar `passCustody`, questionou-se se o carrier deveria auto-declarar-se (claim) ou ser designado. Discussão sênior concluiu que custódia = aceitação de responsabilidade (liability) e não pode ser imposta, logo exige atesto do carrier; MAS o negócio também quer que o manufacturer escolha o carrier (handshake tipo bill-of-lading, assinado pelos dois lados).
- Solução adotada (a mais simples que satisfaz ambos): o **manufacturer designa o carrier já no `createBatch`** (junto do receiver), e o **carrier atesta a aceitação no `passCustody`** (`msg.sender == batch.carrier`). Consentimento bilateral preservado SEM adicionar função (`assignCarrier` descartada), SEM novo status e SEM novo evento. Fica simétrico ao receiver (designado na criação, atesta em `confirmDelivery`).
- Alternativa descartada: `assignCarrier` + novo status `CarrierAssigned` + novo evento. Rejeitada por over-engineering — adicionava um estado/função/evento para obter o mesmo consentimento bilateral que a designação-na-criação já entrega.
- Trade-off aceito: o carrier precisa ser conhecido na origem (cenário real de logística contratada; premissa de modelagem do demo).
- **Fundamento de domínio (nota fiscal):** designar receiver + carrier na criação não é conveniência de modelagem — espelha o instrumento legal real. Uma **nota fiscal** de produto a ser transportado já obriga o emitente (manufacturer) a declarar destinatário (receiver) e transportadora (carrier) na emissão, porque o transportador sai fisicamente com o produto + a nota. O `createBatch` é o análogo on-chain da emissão da nota. O `auditor` (D7) não é campo fiscal literal — é adição do nosso sistema — mas segue o mesmo padrão "papéis definidos no início do processo".
- Impacto na interface: `createBatch(bytes32, address receiver, address carrier)` (ganha `carrier`); `passCustody(bytes32 batchId)` (perde o param `carrier`). Ver D6.

**D6 — `passCustody` perde o parâmetro `carrier` (redundância eliminada):**
- Assinatura antiga: `passCustody(bytes32 batchId, address carrier)`. Nova: `passCustody(bytes32 batchId)`.
- Razão: com o carrier designado no `createBatch` (D5), o carrier passa a vir do storage; no `passCustody` o ator é sempre `msg.sender` (o carrier designado atestando). O parâmetro `carrier` era redundante (sempre teria que ser igual a `msg.sender`). Removê-lo elimina a redundância e uma superfície de erro. Diferente do `BatchCreated` (D3), aqui o param não agregava valor de indexação — `CustodyPassed` já indexa o carrier.

**Nota threat-model (Phase 5) — role checada no ato, não na designação:** nem `RECEIVER_ROLE` nem `CARRIER_ROLE` são checadas no `createBatch`; a role é exigida quando a parte age (`confirmDelivery`/`passCustody`). Consequência: se o manufacturer designar um endereço sem a role correspondente, o batch pode ficar "preso" (não avança além do status onde aquela parte deveria agir). Aceito conscientemente por consistência (mesmo comportamento para receiver e carrier) e mitigável via `blockBatch`. Documentar no threat-model.

**Nota — `carrier` no evento `BatchCreated` como NÃO-indexed:** `BatchCreated` já usa os 3 slots indexed máximos (batchId, manufacturer, receiver). O `carrier` entra como dado não-indexed. Trade-off aceito: NÃO é possível filtrar por topic "todos os batches designados a um carrier antes dele pegar a custódia" — o carrier só vira indexed no `CustodyPassed` (quando aceita). A nota D3 passa a valer para um evento que registra o plano completo (manufacturer → receiver, via carrier).

**D2 — Receiver designado na criação (push+confirm), não claim+approval:**
- Contexto: O receiver é fixado pelo manufacturer em `createBatch(batchId, receiver)` e depois confirma a entrega em `confirmDelivery` (guardado por `msg.sender == batch.receiver`). Foi considerada uma alternativa de "claim + approval" (o receiver se declara via uma operação `claimReceiver`, e um ator responsável valida).
- Decisão: manter push+confirm. Razões: (1) em supply chain o destino é conhecido na origem — há pedido/contrato prévio, ao contrário de marketplaces/leilões onde o comprador aparece depois, cenário em que claim+approval faria sentido; (2) segurança por construção — o receiver é fixado por quem tem autoridade (criador do lote) e ninguém pode se passar por ele, sem risco de "sequestro" de batch por claim aberto; (3) menos transações/gas e sem estados intermediários (batch "sem receiver"). O consentimento do receiver é implícito: se não reconhecer o batch, simplesmente não chama `confirmDelivery`. A "descoberta" de qual endereço corresponde a qual empresa é responsabilidade off-chain (modelo híbrido) — quando chega ao contrato, o endereço já é conhecido.

## Step 1 — Resumo do que foi feito

✅ Implementado:
- `mapping(bytes32 => Batch) private _batches` — storage do contrato
- `_hasBatch(bytes32) private view` — helper para verificar existência (sem revert)
- `hasBatch(bytes32) external view override` — interface pública, delega ao helper
- `getBatch(bytes32) external view override` — retorna batch ou reverte `BatchNotFound`

✅ Aprendizados registrados:
- D1: Por que `mapping private` em vez de `public` (encapsulamento + flexibilidade futura)
- Modificadores de visibilidade: `private` vs `internal` vs `public` vs `external`
- Helper interno (`_hasBatch`) + delegação pública (padrão OpenZeppelin)
- Validação com custom errors

⏳ Testes (Step 1):
- Não há testes Solidity/TS para Step 1 ainda (apenas compilação validou sintaxe)
- Quando chegarmos a Step 2 (`createBatch`), vamos começar testes de happy path + reverts

## Próximo passo

**Step 2: Primeira ação de domínio (`createBatch`)** — sem roles ainda, apenas lógica pura. Vou explicar e você escreve.
