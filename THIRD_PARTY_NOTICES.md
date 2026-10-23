# Third-party notices

This lab is a wrapper around public research and a public proof of concept. The
vulnerability research and the exploit are not original work by the author of
this lab.

## Exploit code

**9bie/php2shell-bypass-aslr-exp**

- Repository: https://github.com/9bie/php2shell-bypass-aslr-exp
- Pinned commit: `17e98ee81025cccfd94b4f9c9a17bf269c65ff75`
- License: none declared in the repository at the time of writing.

The repository is cloned into `.poc/` by `scripts/fetch-poc.sh` at the pinned
commit. It is not vendored into this lab and it is not covered by this lab's
license. Review it before running it.

## Detection rules reference

**ikow/php2shell-poc**, by Qi Deng.

- Repository: https://github.com/ikow/php2shell-poc
- License: MIT
- Used as a reference for detection ideas and rule structure. If any rules are
  copied or adapted into this lab, keep the MIT notice and attribution.

## PHP source snippets

Short excerpts from PHP's Zend engine and session code are used for education.
PHP is distributed under the PHP License 3.01.

- https://github.com/php/php-src
- https://www.php.net/license/3_01.txt

## Research and advisories

These are the sources used to describe the vulnerabilities, timeline, patch,
and mitigations. They are linked, not redistributed.

- PHP security advisory, October 21, 2026:
  https://www.php.net/archive/2026.php#2026-10-21-5
- CVE-2026-109618 advisory:
  https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w
- CVE-2026-109619 advisory:
  https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp
- Calif, "A tale of two PHP remote vulnerabilities":
  https://calif.io/php2shell/
- Wiz Research, "PHP2Shell: AI uncovers critical RCE vulnerabilities":
  https://www.wiz.io/blog/php2shell-php-rce
- Datadog Security Labs, "PHP2Shell: detection, analysis, and remediation":
  https://securitylabs.datadoghq.com/articles/php2shell-critical-vulnerabilities-in-php/
- Rapid7, "Critical Unauthenticated Remote Code Execution in PHP":
  https://www.rapid7.com/blog/post/etr-cve-2026-109618-and-cve-2026-109619-critical-unauthenticated-remote-code-execution-in-php/
- AWS Security Blog, "Amazon Threat Intelligence identifies PHP2Shell
  exploitation prior to public disclosure in MadPot":
  https://aws.amazon.com/blogs/security/amazon-threat-intelligence-identifies-php2shell-exploitation-prior-to-public-disclosure-in-madpot/
- watchTowr, PHP2Shell FAQ:
  https://watchtowr.com/intelligence/php-cve-2026-109618-faq/
- Unit 42, "Threat Brief: Critical Vulnerabilities in PHP":
  https://unit42.paloaltonetworks.com/cve-2026-109618-cve-2026-109619/
- NVD, CVE-2026-109618:
  https://nvd.nist.gov/vuln/detail/CVE-2026-109618
- NVD, CVE-2026-109619:
  https://nvd.nist.gov/vuln/detail/CVE-2026-109619
