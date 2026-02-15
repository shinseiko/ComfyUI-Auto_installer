# Testing Guidelines

## Current State

This project is a PowerShell/batch installer — no test harness exists yet.
Testing is currently manual (run the installer, verify behavior).

## Aspirational: Pester Tests

When a test framework is introduced, use [Pester](https://pester.dev/) for PowerShell:
1. **Unit Tests** - Individual utility functions (UmeAiRTUtils.psm1)
2. **Integration Tests** - Script execution with mocked downloads/installs
3. **Manual Test Matrix** - Full install on clean Windows (venv + Conda paths)

## Test-Driven Development (for new features)

When adding new PowerShell functions:
1. Write Pester test first (RED)
2. Run test - it should FAIL
3. Write minimal implementation (GREEN)
4. Run test - it should PASS
5. Refactor (IMPROVE)

## Coverage Goal: 80%+

Aspirational target once Pester is adopted. Priority order:
1. UmeAiRTUtils.psm1 functions (most testable)
2. Environment detection logic
3. Download/install flows (with mocked externals)
