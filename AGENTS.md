# AGENTS.md — Guía para cualquier AI que trabaje en DROPP

## Stack actual
- n8n (Docker, localhost:5678, webhook URL https://footing-cradling-human.ngrok-free.dev/)
- Supabase (https://hbvrclclsegzccetcdxl.supabase.co)
- Shopify (fm4utx-r2.myshopify.com, USD, PayPal pendiente de confirmar conexión)
- AutoDS (trial 30 días desde 2026-11-23)
- SearchApi (~60 créditos restantes de 100)
- Higgsfield (70 videos disponibles vía socio)
- Gemini 3.5-flash (credencial nHLUcrDMAuqcb3r6 en n8n)

## Reglas de operación
- NO crear nodos Shopify ni AutoDS sin autorización explícita.
- NO cambiar status de products a approved/published — decisión humana.
- NO rotar secretos ni credenciales sin autorización.
- NO borrar workflows existentes.
- NO desactivar RLS en Supabase.
- Si algo se rompe fuera de lo esperado, DETENERSE y registrar en download/BLOCKED_ACTIONS.log.

## Workflows activos
- PR54fGQkhKgwaWZU: Shopify webhook orders/create → Supabase (activo)
- SqtTp6pHFD1uyopA: Shopify token renewal cada 20h (activo, con Manual Trigger añadido)
- hNwyHv5LQAJ8GVNq: Research workflow (inactivo, en fixes — modelo cambiado a gemini-3.5-flash)
- B4sFMVncptK3CbgL: TEMP verificaciones de créditos SearchApi (no borrar)

## Contexto del proyecto
- Para detalles completos, bitácora y pendientes: ver PROJECT_STATUS.md
- Para plan de migración futura a Z Code: ver download/FUTURE_TASK_ZCODE_MIGRATION.md
- Para prompts de ejecución: ver download/PROMPT_*.md

## Estado actual (2026-11-24)
- Fase: BUILD del research workflow. Próximo: ship Jar Opener manualmente.
- Candidate listo para publicar: Jar Opener (margin 78.9%, profit_after_ads $8.39, supplier AliExpress Choice 4.9★).
- Pendiente: confirmar PayPal conectado a Shopify, procesar batch de 30 productos TikTok.
