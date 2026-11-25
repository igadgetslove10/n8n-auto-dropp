# REPORTE ETAPA 4 — Prueba del workflow de research (run 3)

**Fecha:** 2026-11-23 · **Workflow:** `hNwyHv5LQAJ8GVNq` · **Ejecución n8n:** 32 (`run_id` research-32)
**Parámetros:** kitchen gadgets · 3 productos · 40 % · USD 15
**Historial:**
- Run 1 (ejecución 23): fallido, modelo Gemini retirado.
- Run 2 (ejecución 28): 3 discarded (`search_failed` ×2, `parser_failed` ×1).

## 1. Resumen ejecutivo

| Métrica | Valor |
|---|---|
| Duración | 57 s (CLI 19:09:48Z → 19:10:51Z) |
| Ideas | 3 de 3, las mismas del dry-run (vía `ideas_override`) |
| `candidate` | **0** |
| `discarded` | **3**: `no_us_trend` ×3 |
| `incomplete_result` | 0 |
| Filas insertadas | 3 (`save_errors: []`) |
| Créditos SearchApi (panel) | 84 → **75** = **9** |
| `run_stats.searchapi_calls` | **9**, coincide con el panel ✅ |
| Gemini | 4 llamadas (1 ideas + 3 análisis, todas al primer intento con `gemini-3.5-flash` → `modelVersion` gemini-3.6-flash) · 17 745 tokens |

**Conclusión:**

- Los fixes #1, #2 y #3 funcionan.
- El fix #4 (engine nativo) funciona: AliExpress devolvió 60 resultados `/item/` por producto, y Gemini eligió y devolvió una URL `/item/` correcta en los 3 casos.
- Aun así `source_url` quedó en null por un **bug latente desde la primera versión**: `clean()` usaba `new URL()`, que **no existe en el sandbox de Code nodes de n8n** (`URL is not defined`). El `try/catch` lo convertía en null.
- Lo corregí después del run y lo verifiqué offline con los datos del run 3: los 3 productos obtienen su URL. **No lancé un run 4**, porque gastaría ~9 créditos más y no estaba autorizado.

## 2. Fixes aplicados

| Fix | Implementación | Verificación |
|---|---|---|
| #1 Trends "not enough data" → `no_us_trend` | `Compactar evidencia` detecta `error` (string) con "enough data" y no lo cuenta como fallo de búsqueda; marca `trend_no_data`. `Calcular y validar`: `no_us_trend` si `trend_no_data` | Run 3: las 3 respuestas "not enough data" → `no_us_trend` ✅ |
| #2 Contador real | Hallazgo: **los reintentos de n8n nunca ocurrían**. Con `onError=continueRegularOutput` el nodo no lanza error, así que `retryOnFail` no actúa. Ahora `retryOnFail=false` explícito, y cada respuesta recibida cuenta como 1 petición | Panel 9 = `run_stats` 9 ✅. Los runs anteriores sobrecontaban |
| #3 Gemini 503 | `waitBetweenTries` está limitado a **5000 ms** en el código de n8n (`workflow-execute.js`), así que 20 s no es posible como ajuste del nodo. Lo implementé como bucle explícito: `Loop análisis Gemini` (1 producto por vez) → `Intento Gemini` → HTTP (modelo desde el item) → `Evaluar intento Gemini` → `¿Reintentar Gemini?` → `Esperar antes de reintentar` (20 s mismo modelo, 1 s al cambiar de modelo). Plan: 3.5-flash ×3, luego 3.6-flash, 3.7-flash y 2.5-pro. Se guardan `gemini_model_used`, `gemini_model_version` y `gemini_models_tried` | Run 3: 3 de 3 al primer intento. **El camino de reintento/fallback no se ejercitó** (no hubo 503) |
| #4 source_url | SearchApi tiene engines nativos `aliexpress_search`, `aliexpress_store_products` y `aliexpress_product_reviews`. Uso `aliexpress_search` (`delivery_country=US`, `currency=USD`, `language=en_US`, `sort_by=best_match`). Se filtran solo enlaces `/item/`. El prompt exige copiar el `link` exacto; `cost_usd` = `price_usd` de ese resultado. `Calcular` solo acepta una `source_url` que SearchApi devolvió de verdad (`source_url_rejected` si no). **Más el fix de `clean()`** sin `URL` | Engine: 60 resultados `/item/` por producto ✅. `clean()`: verificado en el sandbox real y offline sobre el run 3 ✅. En una ejecución real: pendiente del run 4 |
| Dry-run | `dry_run` + `ideas_override` en `Parámetros de prueba`/`Config`; IF `¿Dry run?` → `Preview queries SearchApi` (sin llamadas) | Dry-run: 0 créditos (84 → 84) ✅ |

Además añadí un NoOp `Análisis completo` (salida *done* del loop), para llegar a 0 avisos de validación.

Backup previo: `C:\Users\ceehv\Desktop\MI AGENTE\backups\workflow_hNwyHv5LQAJ8GVNq_20261123_160400.json`. Validación final: **0 errores, 0 avisos**.

Los `Parámetros de prueba` quedan en `dry_run=true` y `ideas_override=""`: el siguiente run manual solo imprime queries.

## 3. Queries del dry-run (revisadas antes de gastar)

| Producto | Shopping / Trends (`q`) | AliExpress `aliexpress_search` (`q`) |
|---|---|---|
| Electric Spinning Vegetable Dehydrator | electric salad spinner rechargeable | electric salad spinner automatic vegetable dryer |
| Automatic Handheld Can and Jar Opener | electric jar opener hands free | automatic jar opener electric bottle opener |
| High-Pressure Automatic Cup Rinser | sink glass rinser attachment | glass rinser for kitchen sink automatic cup washer |

Valoración: para Shopping y AliExpress tienen sentido (producto concreto, sin marcas). **El riesgo estaba en Trends**: consultas de 4–5 palabras demasiado específicas. Se confirmó, las 3 devolvieron "not enough data".

## 4. Tabla de productos

| title | status | cost_usd | price_usd | gross_margin_pct | profit_after_ads_usd | image_license | rejection_reason |
|---|---|---|---|---|---|---|---|
| Automatic Handheld Can and Jar Opener | discarded | 6.33 | 29.99 | 78.89 | 8.39 | restricted | no_us_trend |
| Automatic High-Pressure Sink Glass Rinser Attachment | discarded | 20.75 | 49.99 | 58.49 | 8.99 | unknown | no_us_trend |
| Rechargeable Electric Salad Spinner & Vegetable Dryer | discarded | 11.53 (+4.50 envío) | 34.99 | 54.19 | 3.20 | restricted | no_us_trend |

`source_url` = null en las 3 filas por el bug de `clean()`. Las URLs que eligió Gemini, ya verificadas contra los resultados de SearchApi:

- Jar Opener: `https://www.aliexpress.us/item/3256807619118033.html` (Choice, rating 4.9, 1 082 vendidos)
- Glass Rinser: `https://www.aliexpress.us/item/3256806811035402.html` (Choice, rating 4.9, 1 153 vendidos)
- Salad Spinner: `https://www.aliexpress.us/item/3256804517692811.html` (rating 5.0, 10 vendidos)

No actualicé las filas: no tengo autorización para hacer UPDATE en `products`.

## 5. Validación de profit_analysis (los 3, a mano)

| Campo | Jar Opener ($29.99) | Glass Rinser ($49.99) | Salad Spinner ($34.99) |
|---|---|---|---|
| gross_margin_pct ≥ 40 | 78.89 ✅ | 58.49 ✅ | 54.19 ✅ |
| gross_margin_usd ≥ 15 | 23.66 ✅ | 29.24 ✅ | 18.96 ✅ |
| payment_fee = p×0.029+0.30 | 1.17 ✅ | 1.75 ✅ | 1.31 ✅ |
| shopify_fee = p×0.02 | 0.60 ✅ | 1.00 ✅ | 0.70 ✅ |
| returns_reserve = p×0.05 | 1.50 ✅ | 2.50 ✅ | 1.75 ✅ |
| cpa_estimate 10–25 | 12 ✅ | 15 ✅ | 12 ✅ |
| profit_before_ads | 20.39 ✅ | 23.99 ✅ | 15.20 ✅ |
| profit_after_ads > 0 | 8.39 ✅ | 8.99 ✅ | 3.20 ✅ (< $5) |
| image_license ∈ {restricted, unknown} | ✅ | ✅ | ✅ |
| image válida | ✅ | ❌ (sin imagen) | ✅ |

`run_stats` del run: searchapi_calls 9 (≤ 15 ✅), gemini_calls 4 (< 30 ✅).

## 6. Consumo

| Recurso | Valor |
|---|---|
| SearchApi run 3 | 9 (3 Shopping + 3 Trends + 3 AliExpress). El panel coincide |
| SearchApi dry-run | 0 |
| `/api/v1/me` (consulta de cuota) | 0 (verificado: 75 → 75) |
| Créditos restantes | **75** |
| Gemini | 4 llamadas, 17 745 tokens |

## 7. Recomendación

**Ninguno se puede aprobar hoy**: los 3 están `discarded` y sin `source_url` en la base de datos.

Qué habría pasado con datos de Trends y la `source_url` corregida (el orden de validación aplica margen, luego trend, luego imagen, luego proveedor):

- **Jar Opener**: el más prometedor. 78.9 % y $8.39 tras ads, imagen válida, proveedor Choice 4.9★ con más de 1 000 vendidos. Merece reinvestigación con una query de Trends más corta ("electric jar opener").
- **Glass Rinser**: buen margen ($8.99 tras ads), pero sin imagen → `image_invalid`. Además el "glass rinser" es un producto muy visto en 2023–24 (riesgo de saturación).
- **Salad Spinner**: $3.20 tras ads (< $5) y proveedor con solo 10 ventas. Descartar.

**Próximos pasos sugeridos (requieren autorización):**

1. **Run 4** (~9 créditos) para verificar `source_url` en una ejecución real. Se pueden reusar estas 3 ideas con `ideas_override`, poniendo `dry_run=false`.
2. **Query de Trends separada y corta**: añadir `trends_query` (1–2 palabras, término principal) al schema de ideas. Hoy Trends usa el mismo `search_query` de 4–5 palabras que Shopping, y en 5 de 6 consultas recientes no hubo datos.
3. Decidir si se hace UPDATE de `source_url` en las 3 filas del run 3 (URLs en §4) o se dejan como históricas.
4. Borrar el workflow temporal `B4sFMVncptK3CbgL` cuando ya no haga falta.

## 8. Acciones bloqueadas / notas

Ver `download/BLOCKED_ACTIONS.log`:

- Run 1: STOP por modelo retirado (resuelto).
- Run 3: STOP antes del run 4 por el bug de `clean()` (corregido, pendiente de verificar en una ejecución real).
- Hallazgos de n8n 2.46.6: no hay `URL` global en los Code nodes; `retryOnFail` no actúa con `onError=continue`; `waitBetweenTries` tiene un tope de 5 s.
- El workflow temporal `B4sFMVncptK3CbgL` sigue existiendo.

Outputs CLI:

- `download/etapa4_cli_execution_23.json.log`
- `download/etapa4_cli_execution_28.json.log`
- `download/etapa4_cli_dryrun.json.log`
- `download/etapa4_cli_execution_32.json.log`

No se publicó nada en Shopify, no se creó nada en AutoDS y no se cambió ningún estado a approved/published.
