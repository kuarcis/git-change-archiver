# Git Patch Generator

A PowerShell script that helps you create a zip file containing changes between two Git commits. This tool is particularly useful when you need to package and share specific changes from your Git repository.

## Features

- Interactive commit selection from the last 50 commits
- Flexible comparison options:
  - Compare any two commits
  - Compare a single commit with HEAD
- Customizable output:
  - Configurable output directory (defaults to `patch/`)
  - Custom filename support with automatic date stamping
  - Choice of line endings (LF or CRLF)
- Preserves directory structure of changed files
- UTF-8 encoding support
- Automatic cleanup of temporary files

## Usage

1. Open PowerShell in your Git repository
2. Run the script:
   ```powershell
   .\uncommited_patch_copy.ps1
   ```
3. Follow the interactive prompts:
   - Select commits by their numbers (1-50)
   - Choose output directory (optional)
   - Specify filename (optional)
   - Select line ending format

## Input Options

### Commit Selection
1. Select the first commit (content in this commit won't be included):
   ```
   Your selection: 3
   ```
2. Select the second commit:
   - Enter a number to select a specific commit
   - Press Enter to use HEAD (current state)
   - Type 'back' to reselect first commit
   ```
   Your selection: [Enter for HEAD]
   ```

### Output Path
- Press Enter to use default (`patch/`)
- Or enter a custom path

### Filename
- Press Enter to use default format: `[oldCommit]_[newCommit]_[date].zip`
- Or enter a custom filename (`.zip` extension will be added automatically)

### Line Endings
- Press Enter or `1` for LF (Unix/Linux style)
- Enter `2` for CRLF (Windows style)

## Output

The script creates a zip file containing:
- All files changed between the selected commits
- Files maintain their original repository structure
- Line endings normalized according to selection

Default output location: `patch/[oldCommit]_[newCommit]_[date].zip`

## Example Output Structure

```
patch/
└── abc123_def456_20250225.zip
    ├── src/
    │   ├── components/
    │   │   └── changed-file.js
    │   └── utils/
    │       └── modified-util.js
    └── config/
        └── updated-config.json