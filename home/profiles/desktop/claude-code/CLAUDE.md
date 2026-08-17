# Global Preferences

## Python

- Always use `uv` for Python projects unless otherwise stated: dependency management, running scripts, creating virtual environments, etc. This includes one-off scripts — use `uv run` with inline script metadata (PEP 723) rather than a global interpreter.
- Use `pytest` for testing. Prefer fixtures for setup/teardown and shared state, and `@pytest.mark.parametrize` for testing multiple input cases.
- Use `ruff` for linting (and formatting), run via a pre-commit hook.
- Use `ty` for type checking.
- Use `prek` ([j178/prek](https://github.com/j178/prek)) to manage pre-commit hooks — a drop-in, faster replacement for `pre-commit` that reads the same `.pre-commit-config.yaml`. Run hooks with `prek run` and install with `prek install`. The `ruff` hook belongs in this config.
