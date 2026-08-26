# Global Preferences

## Python

- Always use `uv` for Python projects unless otherwise stated: dependency management, running scripts, creating virtual environments, etc. This includes one-off scripts: use `uv run` with inline script metadata (PEP 723) rather than a global interpreter.
- Use `pytest` for testing. Prefer fixtures for setup/teardown and shared state, and `@pytest.mark.parametrize` for testing multiple input cases.
- Use `ruff` for linting (and formatting), run via a pre-commit hook.
- Use `ty` for type checking.
- Use `prek` ([j178/prek](https://github.com/j178/prek)) to manage pre-commit hooks. It is a drop-in, faster replacement for `pre-commit` that reads the same `.pre-commit-config.yaml`. Run hooks with `prek run` and install with `prek install`. The `ruff` hook belongs in this config.

## Writing style

Applies to all prose you write: chat replies, commit messages, PR descriptions, docs, comments.

Never use these:

- Em dashes as connectors. Use a comma, a colon, or a full stop.
- Negative parallelism: "it's not just X, it's Y", "this isn't X, it's Y", "rather than X, it's Y".
- Rule-of-three lists where two items carry the meaning.
- These words: delve, leverage, robust, seamless, comprehensive, holistic, nuanced, underscores, showcases, "testament to", "landscape", "realm", "tapestry", "shape" (and "shapes", "shaping") as a verb for influence, "crucial", "vital", "pivotal".
- Trailing "-ing" clauses that restate the sentence: "..., ensuring reliability", "..., making it easier to maintain", "..., highlighting the importance of".
- Vague attribution: "many experts", "it is widely considered", "some argue".
- Closing paragraphs that recap what you just said.
- Bold-lead bullets where a plain sentence works.
- Inflated significance: calling a routine change "significant", "powerful", or "elegant".

Write flat declaratives. State the fact and stop. Prefer the concrete noun over the abstract one: say "the reconcile loop reads the annotation", not "the architecture shapes how state propagates".
