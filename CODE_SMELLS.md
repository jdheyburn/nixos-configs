# Code Smells and Anti-Patterns Analysis

This document provides a comprehensive analysis of code smells and anti-patterns found in this NixOS configuration repository.

**Analysis Date:** 2025-11-11

---

## Critical Issues (Fix Immediately)

### 2. Security: Disabled Build Sandbox
**Location:** `modules/caddy/default.nix:23`, `modules/remote-builder/default.nix:13`

**Issue:** `nix.settings.sandbox = false` disables build sandboxing globally.

**Why it's problematic:** Sandboxing is a critical security feature. Disabling it system-wide for one package (Caddy with plugins) is excessive.

**Fix:** Use `__noChroot = true` on the specific Caddy derivation, or build Caddy with plugins separately and reference the pre-built package:
```nix
# Option 1: In the Caddy package derivation
caddy-with-plugins = pkgs.caddy.overrideAttrs (old: {
  __noChroot = true;
});

# Option 2: Pre-build and use from cache
```

---

### 3. Security: Overly Permissive Sudo
**Location:** `hosts/nixos/common/default.nix:139-145`

**Issue:** User "jdheyburn" has passwordless sudo for ALL commands.

**Why it's problematic:** If this user account is compromised, attacker gets immediate root access.

**Fix:** Limit NOPASSWD to specific commands needed by deploy-rs:
```nix
security.sudo.extraRules = [{
  users = [ "jdheyburn" ];
  commands = [
    { command = "${pkgs.nix}/bin/nix-env"; options = [ "NOPASSWD" ]; }
    { command = "${pkgs.systemd}/bin/systemctl"; options = [ "NOPASSWD" ]; }
    { command = "${pkgs.nix}/bin/nix-store"; options = [ "NOPASSWD" ]; }
  ];
}];
```

---

## High Priority Issues

---

### 5. Duplication: Utility Functions
**Location:**
- `modules/dns/default.nix:8-18`
- `modules/prometheus-stack/scrape-configs.nix:14-25`
- `flake.nix:47-48, 107`

**Issue:** The `isEnabled`, `shouldDNS`, and `isNixOS` functions are duplicated between files. TODOs at scrape-configs.nix:14, 106 acknowledge this.

**Why it's problematic:** Logic duplication makes changes error-prone and increases maintenance burden.

**Fix:** Extract these utility functions into a shared utilities module:
```nix
# lib/utils.nix
{ lib, ... }:
{
  isNixOS = system: !(lib.strings.hasSuffix "darwin" system);

  isEnabled = flake-self: host: modules:
    let
      cfg = flake-self.nixosConfigurations.${host}.config;
    in
      lib.all (path: lib.attrByPath (lib.splitString "." path) false cfg.modules) modules;

  shouldDNS = flake-self: host: modules:
    (isNixOS flake-self.nixosConfigurations.${host}.config.nixpkgs.system) &&
    (isEnabled flake-self host modules);
}
```
Then import and use in modules.

---

### 6. Hardcoded Values: Username in Modules
**Location:**
- `modules/aria2/default.nix:29` (with TODO at line 27)
- `modules/dns/default.nix:62`
- `hosts/nixos/common/default.nix:120-136`

**Issue:** Username "jdheyburn" hardcoded in modules.

**Why it's problematic:** Modules should be user-agnostic. The primary user is already passed via `primaryUser` in flake.nix.

**Fix:** Use `primaryUser` variable (already available in specialArgs) or create module options:
```nix
# In aria2 module
options.modules.aria2 = {
  user = mkOption {
    type = types.str;
    default = primaryUser;
    description = "User to run aria2 as";
  };
};

config = mkIf cfg.enable {
  systemd.tmpfiles.rules = [
    "d /storage/downloads 0770 ${cfg.user} aria2 - -"
  ];
};
```

---

### 7. Hardcoded Values: IP Addresses
**Location:**
- `modules/dns/default.nix:94, 108`
- `modules/nfs-server/default.nix:33, 50`

**Issue:** IP addresses hardcoded in modules: "192.168.1.1:53" for router DNS, "192.168.1.112" for client-specific rules.

**Why it's problematic:** Network changes require code modifications. IP addresses should be configuration, not code.

**Fix:** Add these to catalog.nix:
```nix
# In catalog.nix
infrastructure = {
  router = {
    ip = "192.168.1.1";
    dnsPort = 53;
  };
  clients = {
    specific-device = {
      ip = "192.168.1.112";
      mac = "xx:xx:xx:xx:xx:xx";
    };
  };
};
```
Then reference: `catalog.infrastructure.router.ip`

---

### 8. Implicit Module Dependencies
**Location:** Multiple modules that configure Caddy virtual hosts:
- `modules/dns/default.nix`
- `modules/backup/obsidian.nix`
- `modules/aria2/default.nix`

**Issue:** Many modules configure Caddy virtual hosts but don't formally depend on or check if the Caddy module is enabled.

**Why it's problematic:** Modules could fail if Caddy isn't enabled elsewhere. Order dependencies unclear.

**Fix:** Add assertions to check dependencies:
```nix
config = mkIf cfg.enable {
  assertions = [{
    assertion = config.services.caddy.enable;
    message = "The ${moduleName} module requires Caddy to be enabled";
  }];

  services.caddy.virtualHosts = mkIf config.services.caddy.enable {
    # ... vhost config
  };
};
```

---

## Medium Priority Issues

### 9. Duplicated Build Machine Configuration
**Location:**
- `hosts/nixos/dennis/configuration.nix:68-78`
- `hosts/nixos/dee/configuration.nix:102-112`

**Issue:** Both machines configure "charlie" as a remote builder with nearly identical settings.

**Why it's problematic:** Changes to build machine config need updates in multiple places.

**Fix:** Create a shared module or use catalog.nix:
```nix
# In catalog.nix
buildMachines = {
  charlie = {
    hostName = "charlie.tailscale";
    system = "x86_64-linux";
    protocol = "ssh-ng";
    maxJobs = 4;
    speedFactor = 2;
    supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
  };
};

# In common module or each host
nix.buildMachines = lib.optional
  (config.networking.hostName != "charlie")
  catalog.buildMachines.charlie;
```

---

### 10. Duplication: Repeated Backup Cleanup Command
**Location:**
- `modules/backup/small-files.nix:56-61, 79-84`
- `modules/backup/obsidian.nix:73-77`

**Issue:** Identical bash script for checking exit status and reporting to healthchecks repeated across multiple backup modules.

**Why it's problematic:** Bug fixes or improvements need to be applied in multiple places.

**Fix:** Extract into a common function:
```nix
# In modules/backup/lib.nix
{ lib, pkgs, ... }:
{
  healthcheckWrapper = { healthcheckUrl, scriptName }: ''
    if [ $? -ne 0 ]; then
      ${pkgs.curl}/bin/curl -fsS -m 10 --retry 5 -o /dev/null ${healthcheckUrl}/fail
      echo "${scriptName} errored"
      exit 1
    else
      ${pkgs.curl}/bin/curl -fsS -m 10 --retry 5 -o /dev/null ${healthcheckUrl}
    fi
  '';
}
```

---

### 11. Complex Grafana Configuration
**Location:** `modules/prometheus-stack/grafana.nix` (330 lines)

**Issue:** Single file with 330 lines including extensive alert rules, dashboards, and provisioning.

**Why it's problematic:** Hard to maintain, test, and review. Alert rules should be separate from infrastructure config.

**Fix:** Split into multiple files:
```
modules/prometheus-stack/
├── grafana/
│   ├── default.nix          # Base Grafana service config
│   ├── alerts.nix           # Alert rules
│   ├── dashboards.nix       # Dashboard provisioning
│   └── datasources.nix      # Data source config
```

---

### 12. Hardcoded Email Addresses
**Location:** `modules/prometheus-stack/grafana.nix:53, 77, 88`

**Issue:** Email address "jdheyburn@gmail.com" hardcoded in multiple places in Grafana config.

**Why it's problematic:** Not reusable, makes forking/sharing config harder.

**Fix:** Add to catalog.nix:
```nix
users.jdheyburn = {
  email = "jdheyburn@gmail.com";
  # ... other user attributes
};
```
Reference as: `catalog.users.jdheyburn.email`

---

### 13. Hardcoded Healthcheck URLs
**Location:**
- `modules/backup/small-files.nix:10`
- `modules/backup/obsidian.nix:9`
- `hosts/nixos/charlie/configuration.nix:44`
- `hosts/nixos/dennis/configuration.nix:48`
- `hosts/nixos/dee/configuration.nix:80`

**Issue:** Healthcheck UUIDs hardcoded throughout, making them hard to track and update.

**Why it's problematic:** Changes to healthcheck endpoints require searching through multiple files.

**Fix:** Add to catalog.nix:
```nix
healthchecks = {
  "restic-small-files" = "https://hc.example.com/ping/uuid-here";
  "restic-obsidian" = "https://hc.example.com/ping/uuid-here";
  # ...
};
```

---

### 14. Overly Permissive NFS Export
**Location:** `modules/nfs-server/default.nix:29`

**Issue:** NFS export allows all hosts (`*`) with write access.

**Why it's problematic:** Any device on the network can access and modify NFS data.

**Fix:** Restrict to specific IPs from catalog.nix:
```nix
services.nfs.server.exports = ''
  /storage/share ${catalog.nodes.dee.ip.private}(rw,sync,no_subtree_check,no_root_squash)
  /storage/share ${catalog.nodes.dennis.ip.private}(rw,sync,no_subtree_check,no_root_squash)
'';
```

---

### 15. Security: SSH Keys Without Context
**Location:**
- `hosts/nixos/common/default.nix:131`
- `hosts/nixos/charlie/configuration.nix:22`
- `secrets/secrets.nix:14`

**Issue:** Comments like "Not sure what below is for" next to SSH keys.

**Why it's problematic:** Unknown keys should be investigated or removed for security hygiene.

**Fix:** Audit keys, document their purpose, or remove if no longer needed.

---

### 16. Dead Code: Unused/Commented Configuration
**Location:**
- `hosts/nixos/charlie/configuration.nix:78-81`
- `modules/nfs-server/default.nix:32-53`
- `modules/nfs-client/default.nix:22-27`
- `modules/dns/default.nix:109-131`

**Issue:** Large blocks of commented-out code throughout various modules.

**Why it's problematic:** Makes code harder to read, unclear if code should be kept for future use.

**Fix:** Remove commented code (git history preserves it) or move to documentation if examples are needed.

---

### 17. Dead Code: Disabled Services Still Configured
**Location:**
- `hosts/nixos/charlie/configuration.nix:73-75`
- `hosts/nixos/dee/configuration.nix:20-45, 73, 94-95`

**Issue:** Services configured with `enable = false` (jellyfin, reboot timer, mopidy, navidrome, actualbudget).

**Why it's problematic:** Dead code that clutters configuration.

**Fix:** Remove disabled service configurations unless they're placeholders for imminent re-enabling. If keeping for reference, move to comments with explanation.

---

## Low Priority Issues

### 18. Inconsistent Module Enable Pattern
**Location:** `modules/backup/default.nix`

**Issue:** Most modules have their own enable option, but `backup` module is just a collection of imports without its own enable option.

**Why it's problematic:** Inconsistent module interface makes the system harder to reason about.

**Fix:** Add a parent enable option if needed, or document that it's intentionally just a namespace.

---

### 19. Mixed Secret Declaration Locations
**Issue:** Some secrets declared in host configs (charlie, dennis, dee), some in modules (caddy, aria2, obsidian).

**Why it's problematic:** Makes it unclear where to look for secret declarations, harder to audit.

**Fix:** Establish and document convention: secrets should always be declared in the module that uses them.

---

### 20. Inconsistent `with lib;` Usage
**Location:** Found in 50+ files

**Issue:** Some files use `with lib;` at the top, others don't. Some use both `with lib;` and `with pkgs;`.

**Why it's problematic:** `with` statements can shadow variables and make code harder to debug. NixOS community generally recommends explicit imports.

**Fix:** Prefer explicit `lib.mkEnableOption`, `lib.mkIf`, etc. or use `inherit (lib) mkEnableOption mkIf;`:
```nix
# Preferred approach
{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.modules.myModule;
in
{
  # module definition
}
```

---

### 21. Hardcoded User Paths
**Location:**
- `home/users/joseph.heyburn/default.nix:40`
- `hosts/darwin/mbp/configuration.nix:23`
- `hosts/darwin/macbook/configuration.nix:11`
- `initial.nix:69`

**Issue:** User home directories hardcoded as "/Users/jdheyburn", "/Users/joseph.heyburn", etc.

**Why it's problematic:** NixOS typically manages these automatically. The flake.nix even comments this out at lines 121-125.

**Fix:** Let NixOS/nix-darwin manage home directories automatically. For the NODE_EXTRA_CA_CERTS case, use `config.home.homeDirectory` variable:
```nix
home.sessionVariables = {
  NODE_EXTRA_CA_CERTS = "${config.home.homeDirectory}/certificates/ZscalerRootCertificate-2048-SHA256.crt";
};
```

---

### 22. Duplicate Python Package Declarations
**Location:**
- `home/common/default.nix:3-10`
- `home/users/jdheyburn/default.nix:3-8`

**Issue:** Python packages declaration pattern repeated with slightly different packages.

**Why it's problematic:** Inconsistent approach to Python package management.

**Fix:** Consolidate into a single pattern, potentially in home/common with user-specific overrides.

---

### 23. Complex Tailscale Dispatcher Script
**Location:** `hosts/nixos/common/default.nix:53-100`

**Issue:** Complex bash script with state management for tailscale online detection. Comments indicate it wasn't even needed (lines 51-52).

**Why it's problematic:** Adds complexity without clear benefit. Commented as experimental.

**Fix:** Remove if not needed, or move to a separate module if it is needed with better documentation.

---

### 24. Unused Configuration Files
**Location:**
- `/configuration.nix`
- `/initial.nix`

**Issue:** These appear to be old configuration files not imported by flake.nix.

**Why it's problematic:** Confusing for maintainers, might be edited thinking they're active.

**Fix:** Move to `archive/` or `examples/` directory with clear README explaining their purpose:
```
examples/
├── README.md               # Explains these are examples only
├── initial-setup.nix       # For first-time machine setup
└── standalone-config.nix   # For non-flake usage
```

---

### 25. Incomplete Catalog Usage
**Location:** `flake.nix:172`

**Issue:** Hardcoded user reference with TODO comment "Currently hardcoded to jdheyburn, for paddys".

**Why it's problematic:** Catalog has users section but it's not fully leveraged.

**Fix:** Use catalog.users consistently throughout the configuration.

---

### 26. Inconsistent Module Namespacing
**Issue:**
- Most modules use flat namespacing: `modules.dns`, `modules.caddy`
- Prometheus stack uses nested: `modules.prometheusStack.*`
- Backup uses nested: `modules.backup.*`

**Why it's problematic:** Mix of flat and nested module namespaces without clear pattern.

**Fix:** Document the convention: related modules nest (backup, prometheusStack), standalone modules don't.

---

### 27. Inconsistent File Naming
**Issue:** Most modules use `default.nix`, but some use descriptive names (scrape-configs.nix, networking.nix).

**Why it's problematic:** Makes it harder to find things when all files named `default.nix`.

**Fix:** Use descriptive names for non-default module files consistently, or document when to use each approach.

---

## Positive Observations

The codebase has many strengths worth maintaining:

1. **Excellent catalog.nix pattern** - Centralized service/node management is well-designed
2. **Good use of agenix** - Secrets management is solid (just need to move declarations)
3. **Consistent module structure** - Most modules follow the enable pattern well
4. **Good separation of concerns** - System/user/host configs are well organized
5. **Comprehensive infrastructure** - Well-thought-out homelab setup with monitoring, backups, etc.
6. **deploy-rs integration** - Automated deployment is properly configured

---

## Recommended Action Plan

### Immediate (This Week)
1. Fix security issues:
   - Move initial.nix to examples/ with warnings
   - Fix Caddy sandbox issue
   - Restrict sudo permissions
2. Move secret declarations from host configs to modules
3. Use primaryUser variable instead of hardcoded usernames

### Short Term (This Month)
1. Extract shared utility functions to lib/utils.nix
2. Add IP addresses and emails to catalog.nix
3. Add module dependency assertions for Caddy
4. Clean up commented code and disabled services

### Medium Term (This Quarter)
1. Split complex modules (Grafana, etc.)
2. Consolidate duplicate configurations (build machines, backup scripts)
3. Add module input validation and documentation
4. Improve healthcheck URL management via catalog

### Long Term (Ongoing)
1. Establish and document coding conventions
2. Add type checking and better error messages
3. Improve catalog usage throughout
4. Consider flake-parts for better structure

---

## Convention Documentation

Based on analysis, these patterns should be documented:

1. **Secrets:** Always declare in the module that uses them
2. **Catalog usage:** All IPs, emails, and service definitions go in catalog.nix
3. **Module naming:** Nested for related modules (backup.*), flat for standalone
4. **Dependencies:** Always assert required modules are enabled
5. **User references:** Use primaryUser variable, never hardcode usernames

---

*This analysis was generated by Claude Code. Regular reviews recommended as the codebase evolves.*
