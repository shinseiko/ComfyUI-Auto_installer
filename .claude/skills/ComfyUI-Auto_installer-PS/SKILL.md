```markdown
# ComfyUI-Auto_installer-PS Development Patterns

> Auto-generated skill from repository analysis

## Overview

This skill covers the key development patterns, coding conventions, and workflows used in the `ComfyUI-Auto_installer-PS` repository. The project is a TypeScript-based automation toolkit for installing and managing ComfyUI and its models, primarily using PowerShell scripts. The repository emphasizes maintainable scripting, modular utilities, and clear documentation practices.

## Coding Conventions

- **File Naming:**  
  Use **kebab-case** for all files.  
  _Example:_  
  ```
  scripts/download-flux-models.ps1
  scripts/install-comfyui-phase1.ps1
  ```

- **Import Style:**  
  Use **relative imports** for TypeScript modules.  
  _Example:_  
  ```typescript
  import { downloadModel } from './utils/download';
  ```

- **Export Style:**  
  Use **named exports** for all modules.  
  _Example:_  
  ```typescript
  export function installComfyUI() { ... }
  export const DEFAULT_PATH = '/opt/comfyui';
  ```

- **Commit Messages:**  
  Use prefixes such as `fix:`, `docs:`, `feat:`, `chore:` followed by a concise description (average ~41 characters).  
  _Example:_  
  ```
  feat: add verbosity flags to download scripts
  fix: correct WAN2.1 model URL casing
  ```

## Workflows

### Model Download Script Update
**Trigger:** When model assets change, new models are added, or download logic needs improvement  
**Command:** `/update-model-download-scripts`

1. Edit one or more `scripts/Download-*.ps1` files to update URLs, paths, or logic.
2. Optionally update `scripts/UmeAiRTUtils.psm1` if shared download logic changes.
3. Optionally update `README.md` or `docs/codemaps/backend.md` to document changes.
4. Commit all affected download scripts together.

_Example:_
```powershell
# scripts/Download-FLUX-Models.ps1
Invoke-WebRequest -Uri $modelUrl -OutFile $destinationPath
```

---

### Add or Propagate Verbosity Flags
**Trigger:** When improving user feedback or debugging capabilities across the installer scripts  
**Command:** `/add-verbosity-flags`

1. Add or update `-v`/`-vv` flags in scripts (Install, Update, Bootstrap, Download scripts).
2. Update shared utility module (`scripts/UmeAiRTUtils.psm1`) to support new verbosity levels.
3. Propagate flags through script call chains (e.g., Phase1 → Phase2).
4. Update `README.md` to document new flags.
5. Optionally update `docs/codemaps/backend.md` or `architecture.md`.

_Example:_
```powershell
param([switch]$Verbose, [switch]$VeryVerbose)
if ($Verbose) { Write-Host "Verbose mode enabled" }
```

---

### Documentation, Codemaps, and README Update
**Trigger:** When features, flags, or architecture change and documentation needs to be kept in sync  
**Command:** `/update-docs`

1. Edit `README.md` to document new flags, features, or migration steps.
2. Update `docs/codemaps/*.md` files to reflect backend, architecture, data, or frontend changes.
3. Optionally update `docs/adr/*` for architectural decisions.
4. Commit documentation changes, often alongside or after code changes.

_Example:_
```markdown
## New Verbosity Flags
- `-v`: Enables verbose output
- `-vv`: Enables very verbose output
```

---

### Dependency or Installer Script Update
**Trigger:** When dependencies change, new installer logic is needed, or URLs are updated  
**Command:** `/update-dependencies`

1. Edit `scripts/dependencies.json` to update URLs, SHAs, or version pins.
2. Optionally update installer scripts (`Install-ComfyUI-Phase1.ps1`, `Phase2.ps1`, `Update-ComfyUI.ps1`) to use new dependencies or logic.
3. Optionally update `docs/adr/*` to document rationale.
4. Commit all relevant files together.

_Example:_
```json
{
  "comfyui": {
    "url": "https://github.com/comfyanonymous/ComfyUI/archive/v1.2.3.zip",
    "sha256": "abc123..."
  }
}
```

---

### CI Pipeline or Linting Update
**Trigger:** When improving CI reliability or adapting to new code/linting requirements  
**Command:** `/update-ci`

1. Edit `.github/workflows/ci.yml` to add or update jobs.
2. Optionally add or update `PSScriptAnalyzerSettings.psd1`.
3. Optionally update `.gitignore` for CI artifacts.
4. Commit CI and config changes.

_Example:_
```yaml
# .github/workflows/ci.yml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: npm test
```

## Testing Patterns

- **Test File Naming:**  
  Test files use the `*.test.*` pattern.  
  _Example:_  
  ```
  src/utils/download.test.ts
  ```

- **Framework:**  
  The testing framework is not explicitly specified.  
  _Tip:_ Look for test scripts or configuration in `package.json` or documentation for more details.

- **Test Example:**  
  ```typescript
  // src/utils/download.test.ts
  import { downloadModel } from './download';

  test('downloads model successfully', async () => {
    const result = await downloadModel('test-model');
    expect(result).toBe(true);
  });
  ```

## Commands

| Command                          | Purpose                                                      |
|-----------------------------------|--------------------------------------------------------------|
| /update-model-download-scripts    | Update or fix model download scripts and shared logic         |
| /add-verbosity-flags              | Add or propagate verbosity flags across scripts               |
| /update-docs                      | Update documentation, codemaps, and README                   |
| /update-dependencies              | Update dependencies or installer scripts                     |
| /update-ci                        | Update CI pipeline or linting configuration                  |
```
