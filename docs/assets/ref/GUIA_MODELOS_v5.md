# 🏆 SÚPER GUÍA SDD GENTLE-AI 2026
## Cada fase explicada a fondo + qué modelo top asignarle (y por qué)

> Basada en: documentación oficial de [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai) (README, intended-usage.md, opencode-profiles.md) + benchmarks verificados de junio 2026.

---

## ÍNDICE

1. [¿Qué es SDD y por qué existe?](#1-qué-es-sdd-y-por-qué-existe)
2. [El mapa completo: las 10 fases + el orquestador](#2-el-mapa-completo)
3. [Cada fase explicada en profundidad](#3-cada-fase-explicada-en-profundidad)
4. [Ranking de criticidad: dónde van los modelos top](#4-ranking-de-criticidad)
5. [El arsenal de modelos disponible (junio 2026)](#5-el-arsenal-de-modelos)
6. [TABLA MAESTRA: modelo principal + 2 fallbacks por fase](#6-tabla-maestra)
7. [Justificación detallada fase por fase](#7-justificación-detallada)
8. [Reasoning effort: cuánto "pensar" por fase](#8-reasoning-effort)
9. [Reglas de oro y errores comunes](#9-reglas-de-oro)
10. [Resumen ejecutivo en una pantalla](#10-resumen-ejecutivo)

---

## 1. ¿Qué es SDD y por qué existe?

**SDD = Spec-Driven Development** (desarrollo guiado por especificación).

La idea es simple de entender con una analogía: **no se construye una casa empezando por poner ladrillos**. Primero se inspecciona el terreno, se propone un diseño, se dibujan los planos, se divide la obra en etapas, recién entonces se construye, y al final un inspector verifica que todo cumpla el código de edificación.

SDD hace exactamente eso con el código. En vez de pedirle a la IA "hazme esta feature" y rezar, gentle-ai divide el trabajo en **fases especializadas**, cada una ejecutada por un **sub-agente dedicado** con su propio prompt, sus propias herramientas y — esto es lo importante para esta guía — **su propio modelo de IA asignable**.

### ¿Por qué un modelo distinto por fase?

Porque las fases exigen habilidades distintas:

- Proponer una arquitectura exige **razonamiento profundo** (modelo carísimo y potente).
- Resumir lo que se hizo y archivarlo exige solo **velocidad y bajo costo** (modelo barato).

Usar tu mejor modelo para TODO es como contratar a un arquitecto senior para que también barra la obra: funciona, pero quemas presupuesto (tokens, límites de uso, dinero) donde no aporta nada. Y usar un modelo barato para todo es como dejar que el barrendero diseñe los cimientos: el error se paga multiplicado en todas las fases siguientes.

En gentle-ai esto se configura con **OpenCode SDD Profiles** (`gentle-ai sync --profile` y `--profile-phase`, o desde la TUI). El conductor base es `gentle-orchestrator` y cada perfil genera sub-agentes `sdd-{fase}-{nombre}` con el modelo que elijas.

---

## 2. El mapa completo

El pipeline SDD de gentle-ai tiene **1 orquestador + 10 fases**:

```
                    ┌─────────────────────────┐
                    │   gentle-orchestrator   │  ← El director de orquesta
                    └────────────┬────────────┘
                                 │ delega a...
   ┌──────────┬──────────┬──────┴───┬──────────┬──────────┐
   ▼          ▼          ▼          ▼          ▼          ▼
 PREPARAR   PENSAR     PLANIFICAR  CONSTRUIR  CONTROLAR  CERRAR
 sdd-init   sdd-explore sdd-spec   sdd-apply  sdd-verify sdd-archive
 sdd-onboard sdd-propose sdd-design
                         sdd-tasks
```

**Flujo típico de una feature grande:**

```
init/onboard → explore → propose → spec → design → tasks → apply → verify → archive
  (contexto)   (analizar) (decidir) (documentar)(UI)(dividir)(codear)(auditar)(guardar)
```

El orquestador no ejecuta nada de esto él mismo: **decide cuándo invocar cada fase, en qué orden, y le pasa a cada sub-agente exactamente el contexto y las skills que necesita**. Cada sub-agente guarda sus resultados en Engram (la memoria persistente), así el siguiente retoma donde quedó el anterior, incluso entre sesiones.

---

## 3. Cada fase explicada en profundidad

### 🎼 `gentle-orchestrator` — El director de orquesta

**Qué hace:** Lee tu pedido, evalúa su complejidad, decide si amerita SDD completo o ejecución directa, elige qué fases invocar y en qué orden, resuelve el registro de skills una vez por sesión y le inyecta a cada sub-agente las reglas del proyecto. También aplica las "reglas de delegación" de gentle-ai: si hay que leer 4+ archivos → delega exploración; si se tocan 2+ archivos no triviales → un solo escritor + review fresca; antes de commit/PR → review obligatoria.

**Analogía:** El director de obra. No pone un solo ladrillo, pero si se equivoca asignando cuadrillas, la casa sale mal aunque cada albañil sea excelente.

**Qué necesita del modelo:** *Instruction following* impecable (seguir su prompt al pie de la letra sin "creatividad"), tool routing preciso (llamar al sub-agente correcto con los argumentos correctos), y consistencia en sesiones largas. **No necesita ser el más inteligente** — necesita ser el más obediente y confiable. Además es el agente que más requests acumula (está vivo toda la sesión), así que el costo importa.

---

### 📥 `sdd-init` — El reconocimiento del terreno

**Qué hace:** Primera vez en un proyecto: detecta el stack (lenguajes, frameworks), detecta capacidades de testing y activa Strict TDD Mode si aplica, construye el registro de skills, e ingiere el contexto inicial del repositorio. El orquestador lo corre automáticamente si detecta que no hay contexto.

**Analogía:** El estudio de suelo antes de construir. Es trabajo de inspección y catalogación, no de diseño.

**Qué necesita del modelo:** **Ventana de contexto gigante** (puede tragar repos enteros) y fidelidad al leer (no inventar archivos que no existen). Cero razonamiento profundo: es lectura y clasificación. Aquí mandan contexto largo + costo bajo, no inteligencia.

---

### 🧭 `sdd-onboard` — El tour de bienvenida

**Qué hace:** Introduce un agente "nuevo" a un proyecto que ya tiene historia: lee las specs existentes, la memoria Engram acumulada y la estructura del repo para ponerse al día.

**Analogía:** El primer día de un empleado nuevo: le dan el tour, leen los documentos internos, conocen las decisiones pasadas. No toma decisiones todavía.

**Qué necesita del modelo:** Igual que init — contexto largo, buena comprensión lectora de documentación, costo razonable. Se ejecuta pocas veces, así que tampoco hace falta optimizar al extremo.

---

### 🔍 `sdd-explore` — El detective del codebase

**Qué hace:** Analiza el código existente ANTES de cambiar nada. Mapea dependencias, responde "si toco A, ¿qué se rompe?", identifica los archivos involucrados en un flujo, detecta deuda técnica relevante para la tarea.

**Analogía:** El electricista que revisa toda la instalación antes de tocar un cable, porque sabe que un cable mal cortado puede dejar sin luz a toda la casa.

**Qué necesita del modelo:** **Razonamiento analítico real** sobre mucho código a la vez. Tiene que mantener en la cabeza decenas de archivos y deducir efectos en cadena. Es la primera fase donde un modelo flojo causa daño serio: si explore no detecta una dependencia, propose decide sobre información falsa y todo lo de abajo hereda el error. Contexto largo + razonamiento fuerte.

---

### 💡 `sdd-propose` — El arquitecto (LA FASE MÁS CRÍTICA)

**Qué hace:** Con la información de explore, propone la solución técnica: qué arquitectura usar, qué patrones aplicar, qué trade-offs aceptar (¿Clean Architecture u Hexagonal? ¿inyección de dependencias o singleton? ¿librería nueva o código propio?). Es donde se toman las decisiones que vivirán años en el proyecto.

**Analogía:** El arquitecto que decide si la casa lleva cimientos de hormigón o pilotes. Si el albañil se equivoca, se repara una pared; si el arquitecto se equivoca, se demuele la casa.

**Por qué es la fase #1 en criticidad:** Un error aquí no se ve de inmediato — se ve seis meses después como deuda técnica imposible de pagar. Además, todas las fases siguientes (spec, design, tasks, apply) ejecutan fielmente lo que propose decidió: **si la decisión fue mala, el pipeline entero produce basura con excelente calidad de ejecución**.

**Qué necesita del modelo:** El máximo razonamiento disponible en el mercado. Evaluación de trade-offs, pensamiento a largo plazo, conocimiento profundo de patrones. **Aquí va tu modelo más potente, sin discusión.** El consuelo: propose genera pocos tokens (es una decisión, no una novela), así que pagar el modelo top aquí es barato en términos absolutos.

---

### 📋 `sdd-spec` — El escribano técnico

**Qué hace:** Convierte la propuesta aprobada en un documento Markdown formal: plan de archivos a crear/modificar, criterios de aceptación, contratos de API, casos borde. Es el "contrato" que apply ejecutará.

**Analogía:** El que pasa el boceto del arquitecto a planos técnicos con medidas exactas. No inventa nada nuevo — formaliza con precisión.

**Qué necesita del modelo:** Seguimiento estricto de plantillas, escritura técnica clara, coherencia total con lo que propose decidió (cero "mejoras creativas" por cuenta propia). Es exigente en disciplina, no en genialidad.

---

### 🎨 `sdd-design` — El diseñador de interfaz

**Qué hace:** Define la estructura de componentes UI/UX: jerarquía de componentes (Atomic Design), layouts, estados visuales, accesibilidad. Si le pasas maquetas o screenshots, necesita entenderlas (multimodalidad).

**Analogía:** El diseñador de interiores: la casa ya está decidida estructuralmente, ahora se define cómo se ve y cómo se usa.

**Qué necesita del modelo:** Comprensión visual/espacial y de sistemas de diseño. Es la única fase donde la **multimodalidad** (entender imágenes) puede ser decisiva. Un modelo mediocre en coding pero excelente en visual puede ganar aquí.

---

### ✂️ `sdd-tasks` — El gestor de tickets

**Qué hace:** Parte la spec en tareas pequeñas y ordenadas (tickets/checklist), generalmente como JSON estructurado, con dependencias entre tareas.

**Analogía:** El capataz que convierte los planos en la lista de tareas del día para cada cuadrilla.

**Qué necesita del modelo:** Velocidad, output estructurado limpio (JSON válido), costo mínimo. **Cero razonamiento profundo** — toda la inteligencia ya fue gastada río arriba. Es la fase ideal para el modelo más barato que siga formato bien.

---

### ⚒️ `sdd-apply` — El constructor (2ª FASE MÁS CRÍTICA)

**Qué hace:** Escribe el código real. Implementa archivo por archivo lo que la spec define, siguiendo TDD si está activo, respetando las convenciones del proyecto y las skills inyectadas (React, Go, etc.). Es la fase que más tokens consume por lejos y la que corre más tiempo de forma autónoma.

**Analogía:** La cuadrilla que construye. Los planos pueden ser perfectos, pero si la ejecución es chapucera, la casa se cae igual.

**Qué necesita del modelo:** El mejor modelo de **coding agéntico** disponible: calidad de código (SOLID, patrones), resistencia a degradarse en sesiones largas de cientos de pasos autónomos, lectura precisa de contexto largo (la spec + el código existente). Aquí mandan los benchmarks SWE-bench y Terminal-Bench. **Segunda fase que merece modelo top** — pero ojo: como genera muchísimos tokens, el costo del modelo pega fuerte aquí.

---

### 🔎 `sdd-verify` — El inspector de obra (3ª FASE MÁS CRÍTICA)

**Qué hace:** Audita el código que apply escribió: bugs, vulnerabilidades de seguridad, violaciones de SOLID, code smells, desviaciones de la spec. Es la última línea de defensa antes de que el código llegue a tu repo.

**Analogía:** El inspector municipal que revisa la obra terminada. Si aprueba algo defectuoso, el defecto llega al habitante (producción).

**Regla de oro irrenunciable:** 🚨 **El verificador debe ser un modelo DISTINTO al que escribió el código.** Un modelo revisando su propio código tiene sesgo de confirmación: comete los mismos puntos ciegos al revisar que al escribir. Es como dejar que el albañil se auto-inspeccione. Esto está alineado con la "fresh review rule" de gentle-ai: review con contexto fresco antes de commit/PR.

**Qué necesita del modelo:** Razonamiento crítico sobre código, fortaleza en detección de bugs y seguridad, y *familia distinta* a la del modelo de apply.

---

### 🗄️ `sdd-archive` — El bibliotecario

**Qué hace:** Resume todo el trabajo de la sesión y lo guarda en Engram (memoria persistente) para que futuras sesiones lo recuerden. 100% administrativo.

**Analogía:** Archivar el expediente de la obra terminada. Necesario, pero nadie contrata a un ingeniero para archivar carpetas.

**Qué necesita del modelo:** Compresión de texto fiel y costo mínimo. **El modelo más barato de tu stack va aquí.** Único cuidado: que no alucine al resumir, porque lo que guarde mal lo "recordará" mal para siempre.

---

### ⚖️ Bonus: los agentes Judgment Day (`jd-judge-a`, `jd-judge-b`, `jd-fix-agent`)

Gentle-ai también incluye agentes de "juicio" a nivel workflow (fuera de los perfiles SDD): dos jueces que evalúan de forma adversarial y un agente que corrige. Tienen asignación de modelo independiente. Recomendación corta: los dos jueces deben ser de **familias distintas entre sí** (ej. un Claude y un GPT) para que sus sesgos no coincidan, y el fix-agent debe ser un buen modelo de coding (puede ser el mismo de apply).

---

## 4. Ranking de criticidad

**¿Dónde van los modelos más potentes y top?** En este orden:

| # | Fase | Criticidad | ¿Por qué este puesto? |
|---|------|-----------|----------------------|
| 1 | `sdd-propose` | 🔴 MÁXIMA | Sus errores son invisibles hoy y carísimos mañana. Todo el pipeline ejecuta SU decisión. Pocos tokens → modelo top sale barato aquí. |
| 2 | `sdd-apply` | 🔴 MÁXIMA | Produce el artefacto final: el código. Sesiones autónomas larguísimas. Mucho volumen de tokens. |
| 3 | `sdd-verify` | 🔴 ALTA+ | Última defensa antes del repo. Debe ser tan bueno como apply, y de otra familia. |
| 4 | `gentle-orchestrator` | 🟠 ALTA | Si enruta mal, fases buenas trabajan sobre pedidos equivocados. Pero es routing, no creación: necesita confiabilidad más que genio. |
| 5 | `sdd-explore` | 🟠 ALTA | Garbage in, garbage out: si explora mal, propose decide sobre mentiras. |
| 6 | `sdd-spec` | 🟡 MEDIA | Importante, pero es formalización disciplinada de decisiones ya tomadas. |
| 7 | `sdd-design` | 🟡 MEDIA | Impacta UX, pero los errores son visibles y baratos de corregir. Premia multimodalidad, no potencia bruta. |
| 8 | `sdd-onboard` | 🟡 MEDIA-BAJA | Lectura comprensiva. Se corre poco. |
| 9 | `sdd-init` | 🟢 BAJA | Catalogación. Contexto largo > inteligencia. |
| 10 | `sdd-tasks` | 🟢 BAJA | Particionado mecánico con formato. |
| 11 | `sdd-archive` | 🟢 MÍNIMA | Resumir y guardar. El más barato posible. |

**La regla mental para memorizar:** los modelos top van donde se **decide** (propose), donde se **construye** (apply) y donde se **controla** (verify). Los modelos baratos van donde se **lee** (init, onboard) y donde se **administra** (tasks, archive).

---

## 5. El arsenal de modelos (estado del mercado, junio 2026)

Datos de benchmarks públicos de junio 2026 (BenchLM, LiveBench, SWE-bench, morphllm, kilo.ai):

### Tier S — La élite absoluta

| Modelo | Lo que dicen los datos | Perfil |
|--------|------------------------|--------|
| **Claude Fable 5** (Anthropic) | 95.0% SWE-bench Verified (+6.4 sobre Opus 4.8), contexto 1M, adaptive thinking siempre activo. Output ~$50/MTok — el más caro del mercado. | El mejor modelo del mundo en razonamiento y coding. Se usa quirúrgicamente. |
| **Claude Opus 4.8** | 88.6% SWE-bench Verified (líder entre los "no-Fable"). Output ~$25/MTok. | El caballo de batalla premium para coding agéntico. |
| **GPT-5.3 Codex** (OpenAI) | 85% SWE-bench Verified, **líder en Terminal-Bench**. | Especialista en coding/terminal. Familia distinta a Claude → verificador ideal. |
| **GPT-5.4** | Output ~$15/MTok, fuerte generalista, excelente output estructurado. | Generalista premium, gran instruction following. |
| **Gemini 3.1 Pro** (Google) | Líder LiveCodeBench (Elo 2,887) y líder multimodal/visual (MMMU-Pro ~83%), contexto enorme, output ~$12/MTok. Débil en SWE-bench Pro (~32%). | El rey visual y de contexto largo. NO para escribir código de producción. |

### Tier A — Premium eficiente y open-weight top

| Modelo | Datos | Perfil |
|--------|-------|--------|
| **Claude Sonnet 4.6** | 79.6% SWE-bench Verified, output ~$15/MTok. | Mejor relación confiabilidad/costo de la familia Claude. |
| **Kimi K2.6 (Thinking)** (Moonshot) | Mejor open-source en LiveBench coding (78.57 Coding Avg / 58.33 Agentic). Diseñado para sub-agent parallelism y long-horizon. ~5-6x más barato que Opus. | El "casi-Opus" open-weight. Excelente orquestación. |
| **GLM-5.1** (Z.ai) | 58.4 SWE-bench Pro (supera a GPT-5.4 y Opus 4.6 en ese bench), hasta 8h de ejecución autónoma, 200K contexto, MIT. | Especialista puro en coding agéntico de larga duración. |
| **DeepSeek V4 Pro** | 69.99 Coding Avg / 56.67 Agentic (LiveBench), mejor ratio rendimiento/costo self-hosted. | Analista todoterreno baratísimo. |
| **MiniMax M3** | Recién salido (junio 2026), top open-source emergente. | Comodín nuevo; prometedor pero con menos historial. |

### Tier B — Volumen y tareas ligeras

| Modelo | Perfil |
|--------|--------|
| **DeepSeek V4 Flash** | A ~1.6 puntos del Pro en coding, fracción del costo. El rey del volumen. |
| **Claude Haiku 4.5** | Pequeño pero con disciplina de formato excelente. Ideal tareas estructuradas. |
| **Gemini 3.5 Flash / Flash-Lite** | Contexto 1M baratísimo. Ingesta masiva. |
| **Qwen3.6 (27B/35B)** | 49.5 SWE-Bench Pro, Apache 2.0. Output estructurado sólido. |
| **Nemotron (NVIDIA)** | Razonamiento decente gratis/barato vía NVIDIA. Solo fallback. |

---

## 6. TABLA MAESTRA

> Escenario: tienes acceso a todos los modelos principales del mercado. Formato: **Principal → Fallback 1 → Fallback 2**.

| Fase | 🥇 Principal | 🥈 Fallback 1 | 🥉 Fallback 2 | Effort |
|------|-------------|---------------|---------------|--------|
| `gentle-orchestrator` | **Claude Sonnet 4.6** | GPT-5.4 | Kimi K2.6 | medium |
| `sdd-init` | **Gemini 3.5 Flash** | DeepSeek V4 Flash | Claude Haiku 4.5 | low |
| `sdd-onboard` | **Kimi K2.6** | Gemini 3.5 Flash | Qwen3.6 | low |
| `sdd-explore` | **Gemini 3.1 Pro** | DeepSeek V4 Pro | Claude Sonnet 4.6 | high |
| `sdd-propose` | **Claude Fable 5** 👑 | Claude Opus 4.8 | GPT-5.4 | high/max |
| `sdd-spec` | **GPT-5.4** | Claude Sonnet 4.6 | Qwen3.6 | medium |
| `sdd-design` | **Gemini 3.1 Pro** | GPT-5.4 | MiniMax M3 | medium |
| `sdd-tasks` | **Claude Haiku 4.5** | DeepSeek V4 Flash | Gemini 3.5 Flash-Lite | low |
| `sdd-apply` | **Claude Opus 4.8** | GPT-5.3 Codex | GLM-5.1 | high |
| `sdd-verify` | **GPT-5.3 Codex** | Kimi K2.6 Thinking | DeepSeek V4 Pro | high |
| `sdd-archive` | **DeepSeek V4 Flash** | Claude Haiku 4.5 | Qwen3.6 | none |

**Variante "presupuesto ilimitado":** pon Claude Fable 5 también en `sdd-apply` (95% SWE-bench Verified es el techo del mercado) y Opus 4.8 baja a fallback. Solo recomendable si el costo de $50/MTok output no te duele, porque apply es la fase que más tokens genera.

**Variante "ahorro máximo" (open-weight donde se pueda):** orchestrator→Kimi K2.6, explore→DeepSeek V4 Pro, propose→Kimi K2.6 Thinking, apply→GLM-5.1, verify→DeepSeek V4 Pro, resto→DeepSeek V4 Flash/Qwen3.6. Pierdes ~10-15 puntos de SWE-bench en las fases críticas a cambio de ~90% menos de costo.

---

## 7. Justificación detallada

### `gentle-orchestrator` → Claude Sonnet 4.6

**Por qué NO Fable 5 ni Opus:** El orquestador no crea nada — enruta. Es además el agente con más requests acumuladas de toda la sesión (está vivo siempre). Pagar precios de élite por routing es el error de presupuesto #1.
**Por qué Sonnet 4.6:** La familia Claude tiene el instruction following y tool use más confiable del mercado, y Sonnet lo da a $15/MTok con 79.6% SWE-bench Verified — más que suficiente para entender la complejidad de un pedido y delegarlo bien. Confiabilidad de élite a costo medio.
**Fallback GPT-5.4:** familia distinta (si Anthropic tiene una caída, no pierdes el cerebro central), instruction following igualmente sólido.
**Fallback Kimi K2.6:** diseñado explícitamente para sub-agent parallelism y coordinación long-horizon; el mejor open-weight para este rol si los dos cerrados fallan.

### `sdd-init` → Gemini 3.5 Flash

**Por qué:** Init es tragar repos enteros y catalogar. Gemini Flash combina contexto de 1M tokens con uno de los costos por token más bajos del mercado: exactamente el perfil "mucho contexto, poca inteligencia, muchas pasadas".
**Fallbacks:** DeepSeek V4 Flash (mismo perfil, open-weight, casi gratis) y Haiku 4.5 (si necesitas algo más de fidelidad en la clasificación del stack).

### `sdd-onboard` → Kimi K2.6

**Por qué:** Onboard lee specs + memoria Engram + estructura del repo y tiene que ENTENDER (no solo catalogar como init): qué decisiones se tomaron y por qué. K2.6 tiene 256K de contexto diseñado para no alucinar en lecturas largas y comprensión agéntica real, a precio moderado. Se corre pocas veces, así que el costo extra sobre un Flash es despreciable.
**Fallbacks:** Gemini 3.5 Flash (si el proyecto es gigante y el contexto manda) y Qwen3.6 (lectura comprensiva digna, casi gratis).

### `sdd-explore` → Gemini 3.1 Pro

**Por qué:** Explore es la fase con la combinación más rara: necesita meter MUCHÍSIMO código en contexto Y razonar analíticamente sobre él ("si toco A se rompe B"). Gemini 3.1 Pro es el único tier-S con contexto masivo + razonamiento top + precio razonable ($12/MTok). Su debilidad (escribir código de producción, 32% SWE-bench Pro) **no aplica aquí**: explore lee y analiza, no escribe. Es el ejemplo perfecto de asignar por perfil de tarea y no por fama general.
**Fallbacks:** DeepSeek V4 Pro (56.67 Agentic Avg, análisis sólido baratísimo) y Sonnet 4.6 (si quieres rigor Claude en el análisis).

### `sdd-propose` → Claude Fable 5 👑 (la asignación más importante de toda la guía)

**Por qué Fable 5 va aquí y no en otra fase:** Tres razones que se combinan perfectamente:

1. **Es la fase de mayor apalancamiento.** Una decisión arquitectónica correcta mejora TODO lo que viene después; una mala lo envenena todo. El valor marginal de inteligencia extra es máximo aquí.
2. **Es barata en tokens.** Propose produce una propuesta de unas pocas páginas, no miles de líneas de código. Pagar $50/MTok de output sobre 3.000 tokens de salida cuesta centavos. El modelo más caro del mundo, usado donde casi no genera tokens = élite a precio de ganga.
3. **Adaptive thinking siempre activo.** Fable 5 razona profundo por defecto — exactamente lo que la evaluación de trade-offs necesita (¿Hexagonal o Clean? ¿comprar o construir?).

**Fallbacks:** Opus 4.8 (88.6% SWE-bench V, la segunda mejor cabeza del mercado) y GPT-5.4 (tercera opinión de familia distinta, fuerte en razonamiento general).

### `sdd-spec` → GPT-5.4

**Por qué:** La spec es disciplina de formato: plantillas estrictas, contratos de API, criterios de aceptación. Los modelos GPT llevan años siendo los más sólidos en *structured output* y seguimiento de esquemas, y GPT-5.4 lo hace a precio de tier premium-medio. No hace falta Fable/Opus: la inteligencia ya se gastó en propose; spec formaliza.
**Fallbacks:** Sonnet 4.6 (coherencia y disciplina Claude) y Qwen3.6 (sorprendentemente bueno siguiendo templates, casi gratis).

### `sdd-design` → Gemini 3.1 Pro

**Por qué:** Aquí los datos son contundentes: Gemini 3.1 Pro lidera todo lo multimodal/visual (MMMU-Pro ~83%, líder LiveCodeBench con Elo 2,887). Para entender maquetas, razonar sobre layouts y jerarquías de componentes, no tiene rival. Su debilidad en coding de producción tampoco aplica: design estructura componentes, no implementa (eso es apply).
**Fallbacks:** GPT-5.4 (multimodal competente, segunda opinión) y MiniMax M3 (el nuevo open-weight de junio 2026, perfil creativo-visual prometedor).

### `sdd-tasks` → Claude Haiku 4.5

**Por qué:** Partir una spec en tickets JSON es mecánico. Haiku 4.5 es pequeño, rapidísimo y tiene la disciplina de formato de la familia Claude: JSON válido a la primera, sin desvíos creativos. Pagar más aquí es tirar dinero.
**Fallbacks:** DeepSeek V4 Flash y Gemini Flash-Lite — los dos hacen el trabajo casi gratis.

### `sdd-apply` → Claude Opus 4.8

**Por qué Opus y no Fable 5:** Apply es la fase que MÁS tokens genera (miles de líneas de código + cientos de pasos de agente). Con Fable 5 a $50/MTok output, una feature grande puede costar varias decenas de dólares solo en esta fase. Opus 4.8 da 88.6% SWE-bench Verified — el mejor del mercado después de Fable — a la mitad del precio. Es el punto óptimo calidad/costo para generación masiva de código de producción.
**Por qué no Gemini:** 32% SWE-bench Pro. Los datos confirman el rumor: Gemini NO es para escribir código de producción.
**Fallbacks:** GPT-5.3 Codex (85% SWE-bench V, líder Terminal-Bench — especialista nato en implementación) y GLM-5.1 (el open-weight construido para esto: 8 horas de ejecución autónoma, 58.4 SWE-bench Pro; tu mejor opción si quieres salir de los cerrados).
**Si el dinero no importa:** Fable 5 aquí también, y tienes el techo absoluto del mercado (95%).

### `sdd-verify` → GPT-5.3 Codex

**Por qué:** Dos criterios simultáneos: (1) tiene que ser casi tan bueno en código como apply, y (2) **tiene que ser de otra familia** — un Claude revisando código de Claude comparte puntos ciegos de entrenamiento. GPT-5.3 Codex cumple ambos: 85% SWE-bench Verified, líder en Terminal-Bench (puede EJECUTAR tests y linters durante la auditoría, no solo leer), y es OpenAI revisando a Anthropic: máxima diversidad de sesgo.
**Fallbacks:** Kimi K2.6 Thinking (mejor open-weight en coding según LiveBench, tercera familia de sesgo) y DeepSeek V4 Pro (cuarta familia, análisis sólido barato).
**Nunca:** el mismo modelo de apply, por bueno que sea.

### `sdd-archive` → DeepSeek V4 Flash

**Por qué:** Resumir la sesión y guardarla en Engram es compresión de texto. El Flash es el modelo competente más barato del mercado. Reasoning en `none`: no queremos ni un token de "pensamiento" en una tarea administrativa. Único requisito real: fidelidad al resumir (lo que se archive mal, se recordará mal para siempre) — y el Flash resume fiel.
**Fallbacks:** Haiku 4.5 y Qwen3.6, mismos perfiles.

---

## 8. Reasoning effort

Para modelos que exponen niveles de esfuerzo de razonamiento (gentle-ai los soporta en el picker de perfiles vía el plugin `model-variants`):

| Nivel | Fases | Lógica |
|-------|-------|--------|
| `none` | archive | Administrativo puro. Tokens de razonamiento = dinero quemado. |
| `low` | init, onboard, tasks | Lectura/catalogación/particionado. Procesar, no resolver. |
| `medium` | orchestrator, spec, design | Decisiones de segundo nivel y disciplina de formato. El orquestador decide QUIÉN trabaja, no hace el trabajo. |
| `high` | explore, propose, apply, verify | Las cuatro fases donde el pensamiento profundo paga: análisis de impacto, arquitectura, implementación, auditoría. |
| `xhigh`/max | propose (opcional) | Solo si el modelo lo expone y la decisión es realmente estructural. |

Nota: Fable 5 trae *adaptive thinking* siempre activo (regula solo cuánto pensar), así que en propose no necesitas configurar nada.

---

## 9. Reglas de oro

1. **El dinero va donde se decide, se construye y se controla.** Propose, apply y verify se llevan los modelos top. El resto vive bien con tier B.
2. **Verificador ≠ constructor. Siempre.** Familias distintas en apply y verify. Es la regla más barata de cumplir y la que más bugs atrapa.
3. **El modelo más caro va donde menos tokens se generan.** Por eso Fable 5 brilla en propose (decisiones cortas) y duele en apply (código masivo). Inteligencia máxima × volumen mínimo = ganga.
4. **No asignes por fama, asigna por perfil de tarea.** Gemini es "malo en coding" pero es el MEJOR para explore y design, porque esas fases leen y diseñan, no escriben código de producción.
5. **El orquestador necesita obediencia, no genialidad.** Es el agente con más requests de la sesión: confiable y de costo medio, nunca el más caro.
6. **Fallbacks de familias distintas.** Si tu principal y tus dos fallbacks son del mismo proveedor, una caída del proveedor te deja ciego. Mezcla Anthropic/OpenAI/Google/open-weight.
7. **Revisa esta tabla cada 2-3 meses.** El mercado de modelos cambia rapidísimo (MiniMax M3 salió este mes). Las FASES y sus perfiles de exigencia, en cambio, casi no cambian: aprende los perfiles y solo actualiza los nombres.

### Errores comunes que esta guía te evita

- ❌ Poner el modelo top en TODAS las fases ("total, es el mejor") → quemas límites/dinero en archive y tasks sin ganar nada.
- ❌ Usar Gemini en apply porque "es buenísimo" → es buenísimo en visual y contexto, los benchmarks de coding de producción dicen que no.
- ❌ Mismo modelo en apply y verify → sesgo de confirmación, la auditoría se vuelve teatro.
- ❌ Modelo barato en propose para "ahorrar" → es la fase MÁS barata de premiumizar y la MÁS cara de equivocar.
- ❌ Reasoning `high` en todo → en init/tasks/archive solo genera tokens de pensamiento que pagas y no usas.

---

## 10. Resumen ejecutivo

```
FASE             MODELO PRINCIPAL      FALLBACK 1          FALLBACK 2          EFFORT
──────────────────────────────────────────────────────────────────────────────────────
orchestrator  →  Claude Sonnet 4.6     GPT-5.4             Kimi K2.6           medium
init          →  Gemini 3.5 Flash      DeepSeek V4 Flash   Claude Haiku 4.5    low
onboard       →  Kimi K2.6             Gemini 3.5 Flash    Qwen3.6             low
explore       →  Gemini 3.1 Pro        DeepSeek V4 Pro     Claude Sonnet 4.6   high
propose       →  CLAUDE FABLE 5 👑     Claude Opus 4.8     GPT-5.4             high/max
spec          →  GPT-5.4               Claude Sonnet 4.6   Qwen3.6             medium
design        →  Gemini 3.1 Pro        GPT-5.4             MiniMax M3          medium
tasks         →  Claude Haiku 4.5      DeepSeek V4 Flash   Gemini Flash-Lite   low
apply         →  Claude Opus 4.8       GPT-5.3 Codex       GLM-5.1             high
verify        →  GPT-5.3 Codex         Kimi K2.6 Thinking  DeepSeek V4 Pro     high
archive       →  DeepSeek V4 Flash     Claude Haiku 4.5    Qwen3.6             none
```

**La frase para recordarlo todo:**
> *"Fable decide, Opus construye, Codex controla, Gemini mira y lee, y los Flash hacen el papeleo."*

---

### Fuentes

- [gentle-ai (GitHub)](https://github.com/Gentleman-Programming/gentle-ai) — README, [intended-usage.md](https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/intended-usage.md), [opencode-profiles.md](https://github.com/Gentleman-Programming/gentle-ai/blob/main/docs/opencode-profiles.md)
- [morphllm — Best AI Model for Coding (junio 2026)](https://www.morphllm.com/best-ai-model-for-coding)
- [kilo.ai — Best Open-Source Coding Models 2026](https://kilo.ai/open-source-models)
- [swebench.com — Leaderboards](https://www.swebench.com/)
- [llm-stats.com](https://llm-stats.com/) · [Vellum LLM Leaderboard](https://www.vellum.ai/llm-leaderboard)

*Documento generado el 11 de junio de 2026. Los nombres de modelos cambian rápido; los perfiles de exigencia de cada fase, no. Actualiza la tabla, conserva la lógica.*