# Phase 1 — Main contract (`contracts/SupplyChainDemo.sol`) — Plano Executivo

**Status**: Step 1 ✅ concluído; próximo: Step 2

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

## Checklist de execução (modo tutor — construção por seção)

- [ ] 1. **Modelo de dados puro** — contrato vazio `is ISupplyChainDemo`, `mapping(bytes32 => Batch) private _batches`, `getBatch`/`hasBatch` (view).
- [ ] 2. **Primeira ação: `createBatch`** — validar `receiver != 0`, checar duplicidade, gravar `Batch`, emitir evento.
- [ ] 3. **Controle de acesso** — `AccessControl`, roles (4), constructor, `_requireRole` helper.
- [ ] 4. **Guarda de status + `anchorAudit`** — helpers `_requireStatus`/`_requireExists`, implementar `anchorAudit`.
- [ ] 5. **`passCustody`** — com checagem de autoatesto.
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
