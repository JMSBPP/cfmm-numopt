# GAMS — AI-agent / LLM tooling (Dimension 1) — research notes

## Key finding: no official "GAMS Copilot" or GAMS MCP server (as of June 2026)
- Targeted searches for "GAMS Copilot", "GAMS MCP server", "GAMSPy MCP" returned NO official
  GAMS-branded AI assistant or Model Context Protocol server. MCP search hits were all unrelated
  domains (Unity, GitHub Copilot, SUMO traffic, etc.). Treat any GAMS MCP server as something we
  would have to build ourselves — there is no off-the-shelf one to depend on.
- Implication for the bridge: the agent-callable surface to GAMS today is the Python APIs
  (GAMSPy, gamsapi / GAMS Transfer), not a vendor MCP server.

## GAMSPy = the agent-callable / LLM-friendly authoring layer
- GAMSPy is GAMS's Python-based *algebraic modeling interface*: write models in idiomatic Python
  (Set, Alias, Parameter, Variable, Equation symbols + math package), GAMS execution system handles
  deterministic model generation and solving via free + commercial solvers.
- Python acts mainly as a translator; heavy lifting offloaded to the GAMS backend. This makes it the
  natural target for LLM-assisted model authoring and for an agent to construct/solve models
  programmatically (vs. emitting raw .gms text).
- Maturity/adoption (GAMSPy "at One", Sep 2025 blog): ~7,500 academic licenses in 95 countries,
  adoption at 79 of top 100 universities in its first year. Actively maintained (GAMS-dev/gamspy).

## Authoritative references (dimension 4 contributions for this angle)
- GAMSPy product: https://www.gams.com/products/gamspy/
- GAMSPy docs (readthedocs): https://gamspy.readthedocs.io/en/latest/user/whatisgamspy.html
- GAMSPy GitHub: https://github.com/GAMS-dev/gamspy
- GAMSPy examples GitHub: https://github.com/GAMS-dev/gamspy-examples
- GAMSPy "at One" blog (adoption + roadmap): https://www.gams.com/blog/2025/09/gamspy-at-one-advancing-optimization-in-python/
- GAMSPy intro blog: https://www.gams.com/blog/2024/12/gamspy-high-performance-optimization-in-python/

## Takeaway for the off-chain GAMS <-> on-chain bridge
- For LLM-assisted authoring + agent control, build on GAMSPy (and gamsapi/Transfer for I/O), not a
  hypothetical GAMS Copilot/MCP. If we want an MCP surface, we wrap GAMSPy ourselves.
