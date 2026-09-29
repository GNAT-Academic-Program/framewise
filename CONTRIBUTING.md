# Contributing

## Who owns what

This repository is the **seed**, maintained by AdaCore's GAP
coordinator. It changes only to fix the seed itself (a wrong contract,
a build problem, a port that will not link), and you will be told when
it does so you can rebase; the diff will be small.

Each capstone team works in its own **fork**. Your fork is your
project for the year: branch, experiment, break things. There is no
pull request to this repository during the year.

At the end of the year the strongest work is folded back into the seed
for the next cohort, with credit in the README and the commit history.

## What "keep CI green" means

Your fork inherits the workflow. It builds with warnings as errors,
runs the tests, runs the showcase, and runs SPARK flow analysis. Keep
it green. When you add behaviour, add a test or a proof for it in the
same commit.

Do not weaken a contract or an invariant to make something pass. If a
contract is wrong, fix the contract on its own, with the reasoning in
the commit message, and bring it to the meeting.

## Reviews

Reviews happen on your fork, at the weekly meeting, on the branch you
point to. Come with the diff open.

## Style

GNAT style (`-gnatyg`), 100 columns. Names follow the reference the
README points to where one exists. Every public subprogram has a
comment saying what it guarantees, not how it does it. Commits have a
one-line imperative summary and a body when the summary is not enough.
