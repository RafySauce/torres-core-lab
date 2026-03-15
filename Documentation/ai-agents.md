# Torres-Core — AI Agents

> **Back to index:** [README.md](./README.md)

---

## Strategy

Build incrementally. Prototype on existing hardware, understand the workload, then invest in dedicated infrastructure. Don't buy GPU nodes before knowing what the agents actually need.

| Phase | Compute | Focus |
|-------|---------|-------|
| Now | RTX 4070 + Ollama on gaming PC | Prototype CrewAI workflows |
| Next | Dedicated standalone inference box | Once workflow patterns are understood |
| Later | Multi-GPU (ex-mining 3090s) | Scale as agent workloads grow |

---

## Current Compute

**Gaming PC (CoreGaming)** — Ollama inference host

| Component | Spec |
|-----------|------|
| GPU | RTX 4070 12GB |
| CPU | Ryzen 9 5900X |
| Ollama API | OpenAI-compatible, local endpoint |

Ollama runs on the gaming PC and exposes an OpenAI-compatible API that CrewAI agents on the Docker VM can call over the LAN.

---

## CrewAI — Agent Orchestration

CrewAI is the preferred multi-agent framework. Agents run on the Docker VM (VM 104, `192.168.50.16`) and call Ollama on the gaming PC for inference.

**First agent use cases:**

| Agent | Description | Tools |
|-------|-------------|-------|
| GPU price watcher | Monitors GPU prices, alerts on deals | Web scraping, price history |
| Round-up savings tracker | Rounds up transactions, moves delta to savings | Plaid API, Firefly III |

---

## AI Workflow Engine

A public GitHub-hosted skill library — any AI assistant can fetch and execute workflows on the fly.

**How it works:** AI receives a user request → fetches `index.json` manifest → matches best workflow by tags/description → fetches the `.md` workflow file → follows step-by-step instructions.

**Repo:** `torres-core-workflows` (public GitHub, to be created)

**Design goals:**
- Two HTTP calls to start any workflow (fetch index, fetch workflow)
- Model-agnostic: Claude, ChatGPT, Gemini, local models, any agent framework
- Stateless: each workflow is self-contained
- Human-readable: plain Markdown files with YAML frontmatter

### Repository Structure

```
torres-core-workflows/
├── index.json                    # Manifest — AI fetches this first
├── README.md                     # Human docs + meta-prompt examples
├── workflows/
│   ├── gpu-price-watcher.md
│   ├── roundup-savings.md
│   ├── proxmox-node-deploy.md
│   ├── docker-stack-deploy.md
│   ├── security-audit.md
│   └── revolt-deploy.md
└── .github/workflows/
    └── validate-index.yml        # CI: validates index.json on push
```

### Hosting Tiers

**Tier 1 — Raw GitHub (start here)**

| Property | Value |
|----------|-------|
| Base URL | `https://raw.githubusercontent.com/RafySauce/torres-core-workflows/main/` |
| Latency | 200–500ms |
| Cost | $0 |
| Deploy | `git push` |

**Tier 2 — Cloudflare Worker edge cache**

| Property | Value |
|----------|-------|
| Edge URL | `https://workflows.torres-core.us/` |
| Latency | 10–50ms |
| Cost | $0 (100K req/day free tier) |
| Cache TTL | 5 minutes (stale-while-revalidate) |

The Cloudflare account already manages `torres-core.us` — the Worker is a new route under the existing domain, no additional setup needed.

### Starter Workflows

| ID | Name | Tags |
|----|------|------|
| `gpu-price-watcher` | GPU Price Watcher Setup | ai, automation, hardware, crewai |
| `roundup-savings` | Round-Up Savings Tracker | finance, automation, plaid, python |
| `proxmox-node-deploy` | New Proxmox Node Setup | homelab, proxmox, zfs, infrastructure |
| `docker-stack-deploy` | Docker Service Deployment | docker, portainer, homelab |
| `security-audit` | Lab Security Review | security, hardening, homelab |
| `ha-device-onboard` | Home Assistant Device Setup | homeassistant, zigbee, iot |
| `revolt-deploy` | Revolt Chat Server Setup | docker, cloudflare, communication |

### Meta-Prompt (add to Claude Project)

```
You have access to a workflow library at [BASE_URL]/index.json.
When the user asks for help with a structured task, fetch the index,
find the best matching workflow by description and tags, fetch the
workflow file, and follow its instructions step by step. Always confirm
the workflow choice with the user before proceeding. Gather all required
inputs (listed in frontmatter) before starting. If no workflow matches,
help normally.
```

### Rollout Plan

**Phase A — Repo + first workflows (Day 1, ~1–2 hours)**
1. Create `torres-core-workflows` public repo
2. Write `index.json` with 3–5 starter workflows
3. Author first workflow files
4. Add README with meta-prompt examples
5. GitHub Actions CI to validate `index.json` on push
6. Test by adding meta-prompt to Claude Project and triggering a workflow

**Phase B — Cloudflare Worker (Day 2–3, ~1–2 hours)**
1. `npm install -g wrangler` on gaming PC
2. `wrangler init torres-workflows`
3. Create KV namespace, write Worker (fetch → cache → return)
4. `wrangler deploy`, add DNS route `workflows.torres-core.us`
5. Update `index.json` base URL, add AdGuard DNS rewrite for local resolution

**Phase C — Local agent integration (Week 1–2, ~2–4 hours)**
1. Build `WorkflowFetchTool` for CrewAI (fetches index, matches workflow, returns content)
2. Create "workflow dispatcher" agent that routes user prompts to appropriate workflow
3. Test end-to-end: user prompt → dispatcher → fetch workflow → execute
4. Log results to SQLite or Postgres for iteration

---

## Security Notes

- Workflows are public by design — never include credentials, internal IPs beyond public docs, or API keys in workflow files
- Pin `base_url` in meta-prompt to the exact repo — never allow dynamic repo URLs
- CI lint to flag suspicious patterns (e.g. "ignore previous instructions") in workflow files
- Sensitive config belongs in the AI's system prompt or the user's local environment, not in workflow files

---

*Last updated: March 14, 2026*
