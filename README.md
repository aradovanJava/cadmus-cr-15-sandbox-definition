# CADMUS-CR-15 · Secure Coding Python — sandbox definition

Sandbox definition for the CADMUS CyberRangeᶜᶻ platform (cr.cybersecurity-training.cti.gr) used by
the CADMUS bootcamp **BTCMP-02 Secure Coding**, Cyber Range course
**CADMUS-CR-15 Secure Coding Python**.

It implements section 2 *Training Scenario Architecture* of the
*CADMUS Cyber Range Training Scenario Framework* for CR-15: a Windows 11
developer workstation plus two Docker hosts carrying the SAST and DAST tools.
The application under test is
[`aradovanJava/cadmus-vulnshop-python-cr`](https://github.com/aradovanJava/cadmus-vulnshop-python-cr),
the deliberately vulnerable Flask storefront *cadmus-vulnshop-cr* used by the
course's CR1–CR4 labs (identical to the participant ZIP on the LMS). The N1
lecture lab [`aradovanJava/cadmus-owasp2025-lab-python`](https://github.com/aradovanJava/cadmus-owasp2025-lab-python)
is placed next to it.

> **Training system.** The application contains a working, unauthenticated
> remote code execution path (`/api/import/session`, `pickle.loads`). It binds
> to `127.0.0.1` and is meant to run only inside this sandbox.

## Topology

```
                 internet-connection (WAN)
                           |
                        router  10.10.10.1
                           |
   dev-lan 10.10.10.0/24 --+-----------------------+----------------------+
                           |                       |                      |
                 sc1  10.10.10.10         sq1  10.10.10.20        owz1  10.10.10.30
                 VM1  Windows 11          VM3  SonarQube          VM2  OWASP ZAP
                 trainee workstation      (Docker, SAST)          (Docker, DAST)
                 runs the application
```

| Host | Framework ID | Image | Flavor | Role |
|---|---|---|---|---|
| `sc1` | VM1 · SC1 | `windows-11-x86_64` | `c4_r8_d60` | Developer workstation, RDP access, runs the application |
| `sq1` | VM3 · SQ1 | `ubuntu-noble-x86_64` | `c4_r8_d40` | SonarQube Community Build 26.1 in Docker |
| `owz1` | VM2 · OWZ1 | `ubuntu-noble-x86_64` | `c4_r8_d40` | OWASP ZAP in Docker (desktop UI via Webswing) |
| `router` | — | `debian-12-x86_64` | `standard.small` | Gateway |

### Software on SC1 (framework table 2.1, VM1)

Python 3.14 (python.org, all users), Git with Git Bash, Visual Studio Code with
the Python extension, Node.js LTS, Apache Maven (+ Temurin 21), SQLMap, Snyk
CLI, Postman, SonarScanner CLI.

| Path | What it is |
|---|---|
| `C:\Lab\cadmus-vulnshop-cr` | the application, cloned from the repository above |
| `C:\Lab\cadmus-vulnshop-cr\.venv` | its virtual environment: exactly the pinned `requirements.txt` + pytest |
| `C:\Tools\labtools` | bandit, ruff, pip-audit, cyclonedx-bom in their own environment; commands in `C:\Tools\bin` |
| `C:\Lab\owasp2025-lab` | the N1 lab (port 5000), with its own `.venv` |
| `C:\Lab\scan-sonar.ps1`, `sonar-cr15.properties` | SonarQube analysis of the application |
| `C:\Lab\verify-cr-env.ps1`, `fix-path.ps1` | environment check / PATH repair for a stale session |

## Access

| | |
|---|---|
| Account on all three machines | `user` / `Password123` — the platform's standard sandbox account (administrator on SC1 with RDP, sudo + docker on SQ1/OWZ1) |
| Application on SC1 | `bash tools/run_app.sh` in Git Bash → `http://127.0.0.1:8080/shop` (accounts alice, bob, carol, adminjoe / `Password123`) |
| Application as ZAP sees it | `http://sc1:8080/` |
| OWASP ZAP desktop | `http://owz1:8080/zap/` from SC1; proxy/API on `owz1:8090` |
| SonarQube | `http://localhost:9000` on SC1 (forwarded to SQ1); first login `admin` / `admin`, then a forced password change |

Credentials and every other tunable are in `provisioning/group_vars/all.yml`.

## Design decisions

1. **SQ1 and OWZ1 run Ubuntu 24.04, not Windows 11.** Docker on Windows needs
   nested virtualisation, which OpenStack sandboxes generally do not offer.
   The tools, ports and roles are exactly those of the framework.
2. **The application stays bound to `127.0.0.1`.** Because ZAP is on another
   machine, SC1 forwards `10.10.10.10:8080` to `127.0.0.1:8080`
   (`netsh interface portproxy`) and a Windows Firewall rule admits that port
   from OWZ1 (`10.10.10.30`) only.
3. **`python3` works on Windows.** The course scripts (`tools/run_app.sh`,
   `tools/scan_static.sh`) call `python3`, which on Windows is a Microsoft Store
   alias. A `python3.exe` next to `python.exe` (system Python and `.venv`)
   resolves first. Git Bash is on the PATH and its profile activates the
   application's `.venv`; VS Code's terminal is Git Bash.
4. **The lab tools do not live in the application's environment.** Installed
   there (as the CR1 guide suggests), pip-audit upgrades the deliberately
   outdated `requests 2.25.1` and cyclonedx-bom upgrades `chardet` — changing
   the very dependency set CR1/CR3 analyse. They run from `C:\Tools\labtools`.
   `pip-audit -r requirements.txt` resolves the pins on its own, so results are
   unchanged; for an SBOM of the application's environment use
   `cyclonedx-py environment .venv/Scripts/python.exe`.
5. **PyYAML 5.3.1** (a deliberate pin) has no wheel for Python 3.14. On Linux
   its source build falls back to pure Python; on Windows it stops with
   "Microsoft Visual C++ 14.0 or greater is required", because recent
   setuptools reports the missing compiler with an exception PyYAML 5.3.1 does
   not catch. SC1 builds it once with `--without-libyaml` as a pure-Python
   `py3-none-any` wheel in `C:\Tools\wheelhouse`, and `C:\ProgramData\pip\pip.ini`
   (`find-links`) makes every pip on the machine use it — including a
   trainee's own `pip install -r requirements.txt` and pip-audit.
6. **SonarQube is pinned** (26.1.0.118079 Community, fallback 25.8) and pulled
   from the ECR Public mirror of the Docker Official Image first. Python is
   analysed by the built-in analyser. `C:\Lab\scan-sonar.ps1 -WithLinters`
   also imports the bandit and ruff findings as external issues.
7. **Self-tests at every allocation** (`cr15_self_test`), printed as
   `SELF-TEST …` lines in the user-ansible log:
   - *sq1*: one SonarQube analysis with the trainee's settings; the project and
     token are deleted again (SonarQube starts empty, admin/admin untouched).
   - *sc1*: the course's own scripts in Git Bash — `verify_env.py`,
     `scan_static.sh`, `pip-audit` — and a check that the pins are intact.
   - *sc1 → owz1*: SC1 starts the application; a throwaway ZAP container on
     OWZ1 spiders and active-scans `http://sc1:8080/` exactly as level A2 does
     (the trainee's ZAP session stays empty). The report is kept in
     `/root/cr15-selftest-zap-full.json` on OWZ1. SC1 then stops the
     application, resets its database and restarts.
8. **Level E1 (GitHub Actions)** runs on GitHub, outside the sandbox. Trainees
   fork the application repository and add the workflow in the fork.

## Mapping to the training levels

| Level | Machine(s) | What the sandbox provides |
|---|---|---|
| 0 · Access | SC1 | RDP account, desktop README, environment check |
| A1/A2 · DAST | SC1 → OWZ1 → SC1 | ZAP desktop at `owz1:8080/zap/`, target `http://sc1:8080/` |
| A3/A4 · SAST | SC1 → SQ1 | SonarQube at `localhost:9000`, `scan-sonar.ps1` |
| C1 · Triage | SC1 | bandit, ruff, template scanner (`tools/scan_static.sh`), pip-audit |
| C2/D1 · Fix, commit, redeploy | SC1 | VS Code, Git, the `.venv`, `tools/run_app.sh` |
| E1 · CI/CD | GitHub | Trainee's fork of the application |

## Using it on the platform

1. **Sandboxes → Definition → Create**
   Git URL `https://github.com/aradovanJava/cadmus-cr-15-sandbox-definition.git`,
   revision = the full SHA of the commit to use (not `main`, see below).
2. **Sandboxes → Pool → Create** from that definition; size = number of trainees.
3. **Allocate.** SC1 dominates the time (Python, Chocolatey, VS Code, the
   self-test scan): count on 45–75 minutes for a fresh allocation.
4. Link the pool to the training instance built from the CR-15 training definition.

## Notes for instructors

- **Tested end to end on 31 Oct 2026:** allocation 1576 (commit `0466070`)
  finished all three stages with `failed=0` on sc1, sq1 and owz1; every
  self-test passed, including the ZAP scan of `http://sc1:8080/` from OWZ1
  (High: Cross Site Scripting (Reflected) on `POST /account/login`).
- **Pin the revision.** The platform reads `topology.yml` when the sandbox
  definition is created and does not pick up later commits on a branch.
- **SC1 is managed over SSH** (`mgmt_protocol: ssh`); the Windows 11 image does
  not open WinRM.
- **pip-audit needs internet** (it queries the advisory database at run time).
  The sandbox has it through the router.
- The CR2–CR4 validation harnesses are LMS material; trainees download them
  into `C:\Lab`. pytest is already in the application's `.venv`.
- Snyk requires a free account: trainees run `snyk auth` once.

## Repository layout

```
topology.yml                              hosts, router, network, addressing
provisioning/
├── playbook.yml                          SQ1, OWZ1, SC1, then the end-to-end self-test
├── requirements.yml                      roles and collections
├── group_vars/all.yml                    credentials, IPs, images, versions, switches
└── templates/                            compose files, SC1 scripts and README, self-tests
tools/sc1/                                the SC1 scripts as rendered (for reference)
```

---

Co-funded by the European Union (Digital Europe Programme, grant agreement
101190006 — CADMUS). Views and opinions expressed are those of the author(s)
only and do not necessarily reflect those of the European Union or HaDEA.
