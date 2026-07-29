# Dependabot at CalData

GitHub's [Dependabot](https://github.com/dependabot) provides automated security scanning
of dependencies in repositories hosted in the platform.
It is enabled by default in the `cagov` organization.

## Why Dependabot?

Automated security scans can reduce vulnerabilities in our software dependencies.

## Decisions

1. Group pull requests. This instructs Dependabot to create a single grouped pull request
    for all package security upgrades, rather than a separate pull request for each individual
    security upgrade. We want to enable this grouping to reduce the noise from the alerts
    as a mitigation for [alarm fatigue](https://en.wikipedia.org/wiki/Alarm_fatigue).
1. Use dependency cooldowns. [Dependency cooldowns](https://docs.astral.sh/uv/concepts/resolution/#dependency-cooldowns)
    are a simple and effective way to avoid pulling in compromised
    dependencies. Our primary package manager, `uv`, supports them as a top-level configuration.
1. Avoid specific Dependabot configuration. We try to avoid Dependabot configuration
    via `dependabot.yml` files for operational simplicity. If we ever decide we need
    to include such configuration we will incorporate it into our infrastructure template
    so that all of our repositories share a similar process.

## Repository setup

These steps only need to be done once per repository.

**1. Enable grouped pull requests:**
Dependabot is already enabled by default in all `cagov` repositories.
We still need to enable pull request grouping to avoid getting one
pull request per security upgrade. To enable this, go to
"Settings" → "Advanced Security" and enable "Grouped security updates".
An example grouped pull request is [here](https://github.com/cagov/data-infrastructure/pull/615).

**2. Enable dependency cooldowns:**
In a project `pyproject.toml`, ensure that the following configuration is set:
```toml
[tool.uv]
exclude-newer = "1 week"
```

## Runbook

There are two valid paths for responding to Dependabot alerts:

1. You can merge the auto-generated pull request
2. You can create your own pull request that updates dependencies.

Right now, we recommend the latter approach, as the former requires
some work on our default CI/CD setup.

### Creating your own pull request

1. Check out a new branch with a date slug in the branch name to distinguish it
    from other version upgrade PRs.
    ```bash
    git switch main
    git pull <remote-name> main
    git switch -c security-bump-<YYYY>-<MM>-<DD>
    ```
1. Regenerate the `uv` lockfile with
    ```bash
    uv lock --upgrade
    ```
    This should bring in security
    fixes. It will *also* bring in version bumps for other packages. In some cases these
    incidental patches might *also* be a vector for supply chain attacks. This risk is
    mitigated by using cooldowns as discussed above.
1. Commit and push:
    ```bash
    git add uv.lock
    git commit -m "bump versions"
    git push <remote-name> security-bump-<YYYY>-<MM>-<DD>
    ```
1. Open a pull request against `main` with your branch in GitHub. Once CI passes,
    feel free to merge. We don't need to rely on code review for security patches.
1. Once your pull request is merged, the existing Dependabot PRs should detect it
    and auto-close.

### Merging Dependabot PRs

This workflow currently does not function smoothly because, by default,
Dependabot *does not* have access to repository secrets, and therefore
CI/CD that does things like connect to Snowflake will not work.

A long term fix to this could be the following:

1. Set up GitHub deploy environments for dev and prod.
2. Set up OIDC for GitHub actions to connect to, e.g., Snowflake from the deploy environment.
2. Allow for maintainer approval for PRs coming from services like Dependabot

Once those are configured, maintainers can click "Allow"
on Dependabot security bump PRs, and then CI would run on the Dependabot
PR directly. Maintainers can then merge if CI passes.
