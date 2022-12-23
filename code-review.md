# Conventions for Code Review and GitHub

## The Process

The process for GitHub-based development is:

1. Create a new branch from `main`:
    ```bash
    git switch -c <branch-name>
    ```
1. Develop in your branch. Try to keep commits to single ideas. A branch for a good pull request can tell a story.
1. When your branch is ready for review, push it to GitHub:
    ```bash
    git push <remote-name> <branch-name>
    ```
1. From the GitHub UI, open a pull request for merging your code into `main`.
1. Request one or more reviewers.
1. Go through one or several rounds of review, making changes to your branch as necessary. A healthy review is a conversation, and it's normal to have disagreements.
1. When the reviewer is happy, they can approve and merge the pull request!
1. In general, the author of a PR should not approve and merge their own pull request.
1. Delete your feature branch, it's in `main` now.

## Authoring a pull request

#### Have Empathy

We recommend reading ["Have empathy on pull requests"](https://slack.engineering/on-empathy-pull-requests/)
and ["How about code reviews?"](https://slack.engineering/how-about-code-reviews/)
as nice references for how to be empathetic as the opener of a pull request.

In particular, it's important to remember that *you* are the subject matter expert for a PR.
The reviewer will likely not know anything about the path you took to a particular solution,
what approaches did not work, and what tradeoffs you encountered.
It's your job to communicate that context for reviewers to help them review your code.
This can include comments in the GitHub UI, comments in the code base, and even self-reviews.

#### Try to avoid excessive merge commits

More merge commits in a PR can make review more difficult,
as contents from unrelated work can appear in the code diff.
Sometimes they are necessary for particularly large or long-running branches,
but for most work you should try to avoid them.
The following guidelines can help:

* Usually branch from the latest `main`
* Keep feature branches small and focused on a single problem. It is often helpful for both authors and reviewers to have larger efforts broken up into smaller tasks.
* In some circumstances, a `git rebase` can help keep a feature branch easy to review and reason about.

#### Write Documentation

If your pull request adds any new features or changes any workflows for users
of the project, you should include documentation.
Otherwise, the hard work you did to implement a feature may go unnoticed/unused!
What this looks like will vary from project to project, but might include:

* Sections in a README
* Markdown/rst documents in the repository
* Table metadata in a dbt project.

#### Write Tests

New functionality ideally should have automated tests.
As with documentation, these tests will look different depending upon the project needs.
A good test will:

1. Be separated from production environments
1. If fixing a bug, should actually fix the issue.
1. Guard against regressions
1. Not take so long as to be annoying to run.
1. Not rely on internal implementation details of a project (i.e. use public contracts)

One nice strategy for bugfixes is to write a *failing* test before making a fix,
then verifying that the fix makes the test pass.
It is surprisingly common for tests to accidentally not cover the behavior they are intended to.

## Reviewing a pull request

#### Have Empathy

As above, reviewers should have empathy for the author of a pull request.
You as a reviewer are unaware of the constraints and tradeoffs that an author might have encountered.

Some general tips for conducting productive reviews:

* If there is something you might have done differently, come in with a constructive attitude and try to understand why the author took their approach.
* Keep your reviews timely (ideally provide feedback within 24 hours)
* Try to avoid letting a PR review stretch on too long. A branch with many review cycles stretching for weeks is demoralizing to code authors.
* Remember that perfect is the enemy of the good. A PR that makes an improvement or is a concrete step forward can be merged without having to solve everything. It's perfectly reasonable to open up issues to capture follow-up work from a PR.

#### CI should pass

Before merging a pull request, maintainers should make every effort to ensure that CI passes.
Often this will require looking into the logs of a failed run to see what went wrong,
and alerting the pull request author.
Ideally, no pull request should be merged if there are CI failures,
as broken CI in main can easily mask problems with other PRs,
and a consistently broken CI can be demoralizing for maintainers.

However, in practice, there are occasionally flaky tests,
broken upstream dependencies, and failures that are otherwise obviously not related to the PR at hand.
If that is the case, a reviewer may merge a PR with failing tests,
but they should be prepared to follow up with any failures that result from such an unsafe operation.


*Note: these conventions and recommendations are partially drawn from maintainer guidelines for
[JupyterHub](https://tljh.jupyter.org/en/latest/contributing/code-review.html) and
[Dask](https://docs.dask.org/en/stable/maintainers.html).*


