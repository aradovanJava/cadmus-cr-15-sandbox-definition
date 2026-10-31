CADMUS-CR-15  -  Secure Coding Python  -  Cyber Range sandbox
=============================================================

You are logged in to SC1, the developer workstation (VM1).

Machines in this sandbox
------------------------
  SC1   10.10.10.10   Windows workstation (this machine): Python 3.14, Git + Git Bash,
                        VS Code (Python), Node.js, Maven, SQLMap, Snyk CLI, Postman,
                        SonarScanner CLI. The application runs HERE.
  OWZ1  10.10.10.30   OWASP ZAP (DAST) in Docker
  SQ1   10.10.10.20   SonarQube (SAST) in Docker

Account on all three machines:  user / Password123

The application
---------------
  C:\Lab\cadmus-vulnshop-cr      cadmus-vulnshop-cr (Flask) - the target of the labs
  C:\Lab\cadmus-vulnshop-cr\.venv   its virtual environment: exactly the pinned requirements,
                        plus pytest for the CR2-CR4 harnesses
  bandit, ruff, pip-audit, cyclonedx-py   on the PATH from their own environment
                        (C:\Tools\labtools) - installed into .venv they would upgrade
                        the deliberately outdated pins. Do not "pip install" them there.
                        SBOM of the application's environment:
                          cyclonedx-py environment .venv/Scripts/python.exe -o lab/out/sbom.json

Open "VulnShop terminal (Git Bash)" on the desktop - or VS Code, whose terminal is
Git Bash. The virtual environment is already active there. Then:

  python tools/verify_env.py      environment check of the application
  bash tools/run_app.sh           start it -> http://127.0.0.1:8080/shop
  bash tools/scan_static.sh       bandit + ruff + template scanner -> lab/out/
  bash tools/scan_deps.sh         pip-audit (needs internet)

Training accounts: alice, bob, carol, adminjoe - password Password123.
The course guides write "source .venv/bin/activate"; on Windows the path is
.venv/Scripts/activate (already done for you in Git Bash).

URLs (open them in the browser on SC1)
--------------------------------------
  The application            http://127.0.0.1:8080/shop
  OWASP ZAP desktop          http://owz1:8080/zap/     (proxy port 8090 on owz1)
  ZAP's target               http://sc1:8080/           (SC1 forwards it to 127.0.0.1;
                             only OWZ1 may connect)
  SonarQube                  http://localhost:9000     (forwarded to SQ1:9000)

SonarQube scan
--------------
  powershell -ExecutionPolicy Bypass -File C:\Lab\scan-sonar.ps1 -Token <token>
  First login admin / admin, then set a throwaway password; the token comes from
  My Account -> Security. Settings: C:\Lab\sonar-cr15.properties

Environment check of SC1
------------------------
  powershell -ExecutionPolicy Bypass -File C:\Lab\verify-cr-env.ps1
  A tool reported as "not visible in this window": run C:\Lab\fix-path.ps1

Also here
---------
  C:\Lab\owasp2025-lab         the N1 lecture lab (OWASP Top 10:2025, port 5000):
                             cd C:\Lab\owasp2025-lab ; .venv\Scripts\python app.py
  The CR2-CR4 validation harnesses (cadmus-cr2-validation, cadmus-cr3-validation,
  cadmus-cr4-pipeline) are on the course LMS; download them into C:\Lab.

Level E1 (CI/CD pipeline)
-------------------------
GitHub Actions run on GitHub, not in this sandbox. Fork
https://github.com/aradovanJava/cadmus-vulnshop-python-cr
to your own GitHub account and add the workflow in the fork.

Safety
------
The application is deliberately exploitable and contains an unauthenticated
remote code execution path (/api/import/session). It binds to 127.0.0.1 - do not
change the host, do not expose it, do not enter real data. Reset its state with
  rm -f vulnshop.db
