# t3-code-nix

Nix packages and Home Manager modules for the stable and nightly
[T3 Code](https://t3.codes) desktop client and headless server.

The repository keeps client and server versions together. Each channel has an
official prebuilt variant and a source variant built with Nixpkgs toolchains.
Auto-update is disabled because the flake owns upgrades.

## Platform support

| Package variant | aarch64-darwin | aarch64-linux | x86_64-linux |
| --- | --- | --- | --- |
| Prebuilt client | Yes | No | Yes |
| Source client | Yes | Yes | Yes |
| Prebuilt server | Yes | Yes | Yes |
| Source server | Yes | Yes | Yes |

Upstream does not publish an ARM Linux desktop artifact. Use
`packageVariant = "source"` on `aarch64-linux`. Intel macOS is intentionally
outside the flake's declared systems.

## Add the flake

```nix
{
  inputs.t3-code-nix.url = "github:LisaScheers/t3-code-nix";
}
```

### Direct packages

Stable prebuilt client and server:

```sh
nix run github:LisaScheers/t3-code-nix#t3code
nix run github:LisaScheers/t3-code-nix#t3code-server -- serve
```

Nightly source client and server:

```sh
nix run github:LisaScheers/t3-code-nix#t3code-nightly-source
nix run github:LisaScheers/t3-code-nix#t3code-server-nightly-source -- serve
```

The package names are:

| Client | Server | Channel and variant |
| --- | --- | --- |
| `t3code` | `t3code-server` | Stable prebuilt |
| `t3code-source` | `t3code-server-source` | Stable source |
| `t3code-nightly` | `t3code-server-nightly` | Nightly prebuilt |
| `t3code-nightly-source` | `t3code-server-nightly-source` | Nightly source |

The flake also pins the `averagechris/t3code` OpenCode 2 integration at
`e9ff00018cd91244875e21214be89a15b01a67d7`. Its matching source-built outputs
are `t3code-opencode-v2` and `t3code-server-opencode-v2`; both come from that
exact revision.

### Overlay

```nix
{
  nixpkgs.overlays = [ inputs.t3-code-nix.overlays.default ];
  environment.systemPackages = [ pkgs.t3code ];
}
```

The overlay exports the same names as `packages.<system>`.

## Home Manager

Import the combined module once:

```nix
{
  imports = [ inputs.t3-code-nix.homeModules.t3code ];
}
```

Install the stable prebuilt desktop client:

```nix
{
  programs.t3code = {
    enable = true;
    channel = "stable";
    packageVariant = "prebuilt";
  };
}
```

Install the nightly source client:

```nix
{
  programs.t3code = {
    enable = true;
    channel = "nightly";
    packageVariant = "source";
  };
}
```

The module extends Home Manager's T3 Code settings module, so options such as
`userSettings`, `keybindings`, and `clientSettings` remain available. A direct
`programs.t3code.package` override takes precedence over `channel` and
`packageVariant`.

Run the server as a Linux systemd user service or macOS launch agent:

```nix
{
  services.t3code = {
    enable = true;
    channel = "stable";
    packageVariant = "prebuilt";
    host = "127.0.0.1";
    port = 3773;
    providerPackages = [
      inputs.t3-code-nix.packages.${pkgs.system}.opencode-v2
      pkgs.codex
      pkgs.claude-code
    ];
  };
}
```

Server options also include `package`, `dataDirectory`, `workingDirectory`,
`environment`, and `extraArguments`. The default data directory is
`$XDG_DATA_HOME/t3code`. Desktop-managed state uses T3 Code's normal `~/.t3`
location.

Provider CLIs are discovered through `PATH`. Add declaratively installed
provider packages to `services.t3code.providerPackages`, or supply a package
override that wraps the required tools.

To use the pinned OpenCode 2 integration, override both packages together and
add this flake's OpenCode 2.0.8 package to the service path:

```nix
{
  programs.t3code = {
    enable = true;
    package = inputs.t3-code-nix.packages.${pkgs.system}.t3code-opencode-v2;
  };
  services.t3code = {
    enable = true;
    package = inputs.t3-code-nix.packages.${pkgs.system}.t3code-server-opencode-v2;
    providerPackages = [
      inputs.t3-code-nix.packages.${pkgs.system}.opencode-v2
    ];
  };
}
```

Do not substitute `pkgs.opencode`; that package is the incompatible OpenCode 1
provider. The wrappers and service both disable auto-update.

When client and server are enabled in the same Home Manager configuration,
evaluation rejects different versions. Prebuilt and source packages can be
mixed when their release versions match.

The server binds to `127.0.0.1` by default. Setting `host = "0.0.0.0"` exposes
it to the network and should be paired with appropriate access controls.

## Release channels and source builds

`stable` follows the npm `latest` dist-tag. `nightly` follows the npm `nightly`
dist-tag. The updater accepts a release only when the exact npm version and
GitHub release tag match and all expected desktop artifacts exist.

Prebuilt clients repackage the immutable GitHub release assets. Prebuilt
servers install the exact `t3@version` npm package with a committed lock file.
Source packages fetch the matching Git tag and use pinned pnpm, Cargo, Node,
and Electron inputs from Nixpkgs. Client and server selectors share the
expensive source build and resource-monitor derivation.

Source-built macOS applications are unsigned. Source builds also omit
upstream's private release credentials and production cloud configuration, so
T3 Connect may be unavailable until upstream documents reusable public values.

### Build a client and server from another revision

`lib.mkSourcePackages` builds both applications from one explicitly supplied
source tree. This is useful for forks and unreleased revisions while keeping
the web client and server protocol in sync:

```nix
{
  inputs.t3code-src = {
    url = "github:averagechris/t3code/<revision>";
    flake = false;
  };

  outputs = { nixpkgs, t3-code-nix, t3code-src, ... }:
    let
      pkgs = import nixpkgs { system = "aarch64-darwin"; };
      custom = t3-code-nix.lib.mkSourcePackages pkgs {
        src = t3code-src;
        version = "0.0.43-opencode2";
        pnpmHash = "sha256-...";
        cargoHash = "sha256-...";
        pnpmVersion = "11.10.0";
        electronVersion = "44.1.0";
      };
    in {
      # Pass this module to home-manager.lib.homeManagerConfiguration.
      homeModules.custom-t3code = {
        programs.t3code.package = custom.client;
        services.t3code = {
          package = custom.server;
          providerPackages = [ t3-code-nix.packages.${pkgs.system}.opencode-v2 ];
        };
      };
    };
}
```

Use the dependency hashes reported by the first build attempt. Both wrappers
continue to disable T3 Code auto-update. Direct package overrides are existing
Home Manager API, so stable and nightly channel selection is unchanged.

## Updates

The main branch's GitHub Actions updater checks both channels at minute 17 of every hour. Upstream checks
nightly releases every three hours, so a complete release normally appears
here within one additional hour. GitHub schedules are best effort.

Run the same updater locally:

```sh
nix develop -c ./scripts/update-releases stable
nix develop -c ./scripts/update-releases nightly
nix develop -c ./scripts/update-releases all
```

An incomplete upstream release leaves the repository unchanged. A successful
update refreshes the source, pnpm, Cargo, npm, and desktop artifact hashes. CI
opens one long-lived pull request per channel and enables squash auto-merge
after all package and module checks pass.

The workflow expects `T3CODE_UPDATE_TOKEN`: a GitHub App installation token or
fine-grained bot token with repository contents and pull request write access.

The weekly flake-input workflow remains separate from T3 Code release updates.

### OpenCode 2 pin maintenance

The OpenCode 2 fork is a manual pin. It does not use the hourly updater or
auto-merge. Use `gh auth status` before checking the published fork. Keep the
T3 and Nix work separate:

1. Start in the Bay T3 feature workspace, the workspace that contains the
   `opencode-v2` bookmark, for T3 commands.
2. Start in the Bay Nix feature workspace, the workspace based on
   `opencode-v2-pin`, for Nix commands.

Do not run either procedure from an unrelated checkout. The commands below do
not depend on a particular Bay path.

#### Refresh and verify the T3 feature commit

Run this block in the Bay T3 feature workspace. Check the remotes once. If
`upstream` is already listed, do not add it again.

```sh
jj status
jj git remote list
```

If the remote list has no `upstream` entry, add it once and rerun the fetch:

```sh
jj git remote add upstream https://github.com/pingdotgg/t3code.git
```

Then fetch only upstream `main` and rebase the feature commit:

```sh
jj git fetch --remote upstream --branch main
jj log -r 'main@upstream ~ ancestors(opencode-v2)' -n 12 \
  --no-pager --color=never
jj rebase -r opencode-v2 -d main@upstream
jj new opencode-v2
```

The log is read-only. Review those commits before rebasing so upstream drift is
visible instead of being folded into the feature commit without review.

`-r` rebases only the `opencode-v2` commit. It does not move unrelated
descendants, so `jj new opencode-v2` makes the current workspace see the
rebased tree rather than leaving its existing `@` child on the old parent. If
jj reports conflicts, resolve the conflict markers and run `jj status` before
continuing.

Confirm the published feature commit and its parent, then run the focused tests
that this pin adds. These are the `t3` package's existing scripts and the seven
OpenCode provider tests, not the full server test suite.

```sh
gh auth status
gh api repos/averagechris/t3code/branches/opencode-v2 --jq .commit.sha
gh api repos/averagechris/t3code/commits/opencode-v2 --jq '.parents[].sha'

# Run from the T3 repository root.
vp -C apps/server test run \
  src/provider/Layers/OpenCodeAdapter.test.ts \
  src/provider/Layers/OpenCodeProvider.test.ts \
  src/provider/openCodeV2Client.test.ts \
  src/provider/opencodeRuntime.environment.test.ts \
  src/provider/opencodeRuntime.inventory.test.ts \
  src/provider/opencodeRuntime.permissions.test.ts \
  src/textGeneration/OpenCodeTextGeneration.test.ts
vp run --filter t3 typecheck
vp lint apps/server/src/provider apps/server/src/textGeneration
pnpm --filter t3 run build:bundle
```

Review the result, then publish only the T3 bookmark. This procedure does not
create a T3 pull request or change the Nix repository.

```sh
jj status
jj git push --bookmark opencode-v2 --dry-run
jj git push --bookmark opencode-v2
```

#### Update and verify the Nix pin

Run this block in the Bay Nix feature workspace. Set
`inputs.t3code-opencode-v2-src.url` in `flake.nix` to the full commit SHA
reported by the T3 workspace, for example
`github:averagechris/t3code/<full-sha>`. Then update only that flake input:

Ensure this Nix workspace has an `upstream` remote before fetching. If it does
not, add `https://github.com/LisaScheers/t3-code-nix.git` once with the same
`jj git remote list` and `jj git remote add` check used above.

```sh
# Refresh the remote-tracking view of upstream without moving local `main`.
jj git fetch --remote upstream --branch main
jj log -r 'main@upstream ~ ancestors(opencode-v2-pin@origin)' -n 12 \
  --no-pager --color=never

# Carry the Nix feature stack onto latest upstream before updating the pin.
jj git fetch --remote origin --branch opencode-v2-pin
jj rebase -b opencode-v2-pin -d main@upstream
jj status
# Resolve any conflicts before continuing to the pin update or builds.

nix flake update t3code-opencode-v2-src

nix build --no-link \
  .#packages.aarch64-darwin.opencode-v2 \
  .#packages.aarch64-darwin.t3code-opencode-v2 \
  .#packages.aarch64-darwin.t3code-server-opencode-v2
# If a fixed-output hash changed, copy the reported "got" hash into
# flake-parts/pkgs/default.nix and rerun the build.

# Evaluate the Home Manager check on both declared Linux systems.
nix eval --raw .#checks.aarch64-linux.home-module.drvPath
nix eval --raw .#checks.x86_64-linux.home-module.drvPath

# Confirm that the lock and fetched source name the same full revision.
lock_rev="$(jq -r '.nodes."t3code-opencode-v2-src".locked.rev' flake.lock)"
source_rev="$(nix eval --raw --impure --expr \
  'let flake = builtins.getFlake (toString ./.); in flake.inputs.t3code-opencode-v2-src.rev')"
test "$lock_rev" = "$source_rev"
printf 't3code-opencode-v2-src: %s\n' "$lock_rev"

nix flake check --all-systems --no-build --no-write-lock-file
nix build --no-link --dry-run \
  .#packages.aarch64-darwin.opencode-v2 \
  .#packages.aarch64-darwin.t3code-opencode-v2 \
  .#packages.aarch64-darwin.t3code-server-opencode-v2
```

The flake check also evaluates the Home Manager modules on Darwin. Its
`opencode-v2` CI job builds these same three aarch64-darwin attributes, checks
that the client and server versions match, checks the locked OpenCode version,
and verifies that both wrappers contain `T3CODE_DISABLE_AUTO_UPDATE`.

If there is no Nix drift, the rebase is a no-op when `opencode-v2-pin` is
already based on the latest `main@upstream`; this does not mutate `main` or
publish the feature branch.

#### Open a Nix pull request

Only after the local checks pass, create a Nix review bookmark from the existing
`opencode-v2-pin@origin` base. Do this in a clean Bay Nix feature workspace. A
pushed `opencode-v2-nix-refresh` bookmark is the only ref published by this
block.

```sh
jj git fetch --remote origin --branch opencode-v2-pin
jj new opencode-v2-pin@origin -m 'build(nix): refresh OpenCode 2 pin'

# Restore only the verified Nix change. Set this to the change ID printed by
# `jj log` in the workspace where the checks passed.
: "${VERIFIED_NIX_CHANGE:?Set VERIFIED_NIX_CHANGE to that verified change ID}"
jj restore --from "$VERIFIED_NIX_CHANGE" \
  README.md flake.nix flake.lock flake-parts/pkgs/default.nix

# Check the exact review diff against the fetched base. The first command
# must print only the four paths restored above.
jj diff --from opencode-v2-pin@origin --to @ --name-only
jj diff --from opencode-v2-pin@origin --to @ --stat
jj bookmark set opencode-v2-nix-refresh -r @
nix flake check --all-systems --no-build --no-write-lock-file

jj git push --bookmark opencode-v2-nix-refresh --dry-run
jj git push --bookmark opencode-v2-nix-refresh
gh pr create --base opencode-v2-pin --head opencode-v2-nix-refresh \
  --title 'build(nix): refresh OpenCode 2 pin' \
  --body 'Refresh the pinned OpenCode 2 T3 source commit.'
```

For a review branch that already exists, rebase its single commit onto the
current `opencode-v2-pin@origin` bookmark instead of creating another bookmark:
`jj rebase -r opencode-v2-nix-refresh -d opencode-v2-pin@origin`. Pushing that same
bookmark updates its existing pull request; do not run `gh pr create` again.
Do not enable auto-merge. The workflow evaluates this pull request on its
`opencode-v2-pin` base branch.
