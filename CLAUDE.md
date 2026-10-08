# CLAUDE.md

Read and obey **[AGENTS.md](./AGENTS.md)** before making any changes to this repository.

`AGENTS.md` is the authoritative development contract for WildGuard. It defines:

- the four graded parent business use cases (UC01–UC04) and their owners/branches
- non-negotiable domain, enum, Firestore, and offline-sync rules
- role access, authentication boundaries, and route security
- architecture, testing, git, and "definition of done" requirements
- explicit restrictions on what AI agents must NOT change automatically

If a requested change conflicts with `AGENTS.md`, STOP and explain the conflict before modifying code. Do not weaken, reinterpret, or bypass those rules.
