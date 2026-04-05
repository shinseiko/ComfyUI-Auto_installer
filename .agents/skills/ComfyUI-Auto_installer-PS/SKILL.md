```markdown
# ComfyUI-Auto_installer-PS Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill outlines the development conventions and workflows for the `ComfyUI-Auto_installer-PS` repository, a TypeScript project designed to automate installation tasks for ComfyUI. The repository uses conventional commit messages, follows specific coding styles, and supports the addition of new ECC bundle components through a structured workflow. This guide will help you contribute effectively by adhering to the established patterns for code, documentation, and workflow automation.

## Coding Conventions

### File Naming
- Use **camelCase** for file names.
  - Example: `autoInstaller.ts`, `installScript.ts`

### Import Style
- Use **relative imports** for internal modules.
  - Example:
    ```typescript
    import { installDependencies } from './dependencyManager';
    ```

### Export Style
- Use **named exports**.
  - Example:
    ```typescript
    // dependencyManager.ts
    export function installDependencies() { ... }
    ```

### Commit Messages
- Follow the **conventional commit** format.
- Use the `feat` prefix for new features.
  - Example:  
    ```
    feat: add support for custom plugin installation via CLI
    ```

## Workflows

### Add ECC Bundle Component
**Trigger:** When you want to register a new skill or agent as an ECC bundle in the system.  
**Command:** `/add-ecc-bundle`

Follow these steps to add a new ECC bundle component:

1. **Register the tool:**
   - Create or update `.claude/ecc-tools.json` to include the new tool/skill/agent.
     ```json
     {
       "tools": [
         { "name": "MySkill", "path": ".claude/skills/MySkill/" }
       ]
     }
     ```
2. **Document the skill:**
   - Add a `SKILL.md` file in `.claude/skills/<SkillName>/` and/or `.agents/skills/<SkillName>/`.
3. **Configure the agent:**
   - Add agent configuration (e.g., `openai.yaml`) in `.agents/skills/<SkillName>/agents/`.
4. **Update identity:**
   - Add or update `.claude/identity.json` with relevant identity information.
5. **Update codex configuration:**
   - Create or update `.codex/config.toml` and `.codex/AGENTS.md` to register the agent.
6. **Add agent TOML files:**
   - Place agent-specific TOML files in `.codex/agents/`.
7. **Define instincts:**
   - Add instincts YAML files in `.claude/homunculus/instincts/inherited/`, e.g., `mySkill-instincts.yaml`.
8. **Document commands:**
   - Add or update command documentation in `.claude/commands/`.

**Example Directory Structure:**
```
.claude/
  ecc-tools.json
  skills/
    MySkill/
      SKILL.md
  identity.json
  homunculus/
    instincts/
      inherited/
        mySkill-instincts.yaml
  commands/
    mySkill-command.md
.agents/
  skills/
    MySkill/
      SKILL.md
      agents/
        openai.yaml
.codex/
  config.toml
  AGENTS.md
  agents/
    mySkill.toml
```

## Testing Patterns

- **Test File Naming:** Test files follow the `*.test.*` pattern, e.g., `autoInstaller.test.ts`.
- **Testing Framework:** The specific framework is unknown, but standard TypeScript testing practices are assumed.
- **Example Test File:**
  ```typescript
  // autoInstaller.test.ts
  import { installDependencies } from './dependencyManager';

  describe('installDependencies', () => {
    it('should install all required dependencies', () => {
      // Test implementation here
    });
  });
  ```

## Commands

| Command           | Purpose                                                    |
|-------------------|------------------------------------------------------------|
| /add-ecc-bundle   | Automate the process of adding a new ECC bundle component. |

```