# Claude Code permission rules (https://code.claude.com/docs/en/permissions),
# imported by settings.nix as `permissions`. `@memoryDir@` is substituted at
# build time.
{
  allow = [
    "Bash(jj log:*)"
    "Bash(jj status:*)"
    "Bash(jj show:*)"
    "Bash(jj diff:*)"
    "Bash(jj new:*)"
    "Bash(jj squash:*)"
    "Bash(jj split:*)"
    "Bash(jj edit:*)"
    "Bash(jj describe:*)"
    "Bash(jj commit:*)"
    "Bash(jj rebase:*)"
    "Bash(mvn test:*)"
    "Bash(mvn compile:*)"
  ];
  deny = [];
  ask = [];
  additionalDirectories = ["@memoryDir@"];
}
