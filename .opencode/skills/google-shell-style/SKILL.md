---
name: google-shell-style
description: Apply Google Shell Style Guide to .sh files in this repository. Use when editing, creating, or reviewing shell scripts (*.sh). Covers: shebang, set flags, indentation, quoting, variable expansion, function naming, local variables, [[ ]], arrays, pipelines, comments, main function, readonly constants.
---

# Google Shell Style Guide

Enforce [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) for all `.sh` files in this repository.

## Shebang and set flags

- Every executable script must start with `#!/bin/bash`
- Use `set -euo pipefail` early in the script
- Libraries (non-executable `.sh` files sourced by other scripts) may omit shebang but still start with a file header comment

## Indentation and formatting

- Indent 2 spaces, never tabs
- Maximum line length: 80 characters
- Use blank lines between blocks to improve readability
- Pipelines: if they don't fit on one line, split one pipe segment per line with `|` at the start of the continuation line and 2-space indent. Put `\` before the newline for the pipe:
  ```bash
  command1 \
    | command2 \
    | command3
  ```
- Control flow: `; then` and `; do` on the same line as `if`/`for`/`while`. `else`, `fi`, `done` on their own lines aligned with the opening statement.

## Quoting and variable expansion

- Always quote variables: use `"${var}"` form (prefer braces for all variables except single-char shell specials like `$1`, `$#`, `$$`, `$?`)
- Never leave variable expansions unquoted unless you intentionally need word splitting
- Use `"$@"` for passing arguments, never `$*` or unquoted `$@`
- Use single quotes when no substitution is needed, double quotes when substitution is required
- For pattern matches inside `[[ ]]`, follow the guide's quoting rules (RHS of `=~` must NOT be quoted)

## Command substitution

- Use `$(command)` never backticks

## Tests and conditionals

- Always use `[[ ]]` never `[ ]` or `test` or `/usr/bin/[`
- Use `==` for string equality (not `=`)
- Use `(( ))` for arithmetic comparisons, not `[[ ]]` with `<`/`>`
- Use `-z` / `-n` explicitly for empty/non-empty string tests
- Use `(( ))` or `$(( ))` for arithmetic, never `let`, `$[ ]`, or `expr`

## Arrays

- Use bash arrays for lists of elements, especially command arguments
- Declare with `declare -a` or parentheses
- Always expand as `"${array[@]}"`

## Pipes to while

- Never pipe into `while` — use process substitution `< <(command)` or `readarray` instead
- Pipes create a subshell, losing variable modifications

## Functions

- Lowercase names with underscores: `my_func`
- Use `funcname() { }` form (the `function` keyword is optional but must be used consistently if chosen)
- Braces on the same line as the function name
- All function-specific variables must be declared `local`
- Declaration and assignment must be separate statements when the value comes from command substitution:
  ```bash
  local my_var
  my_var="$(some_command)" || return
  ```
- Never do `local my_var="$(some_command)"` — `$?` will be 0 from `local`, not the command

## Function comments

- Any function that is not both obvious and short must have a header comment
- Use the `########` block format with sections: description, Globals, Arguments, Outputs, Returns
- Example:
  ```bash
  #######################################
  # Description of the function.
  # Globals:
  #   VAR_NAME
  # Arguments:
  #   arg description
  # Outputs:
  #   Writes result to stdout
  # Returns:
  #   0 on success, non-zero on error.
  #######################################
  my_func() {
  ```

## File header

- Every file must start with a comment describing its contents
- Example:
  ```bash
  #!/bin/bash
  #
  # Brief description of what the script does.
  ```

## Naming conventions

- Functions and variables: lowercase with underscores
- Constants and exported/env vars: UPPER_CASE_WITH_UNDERSCORES, declared `readonly` at the top
- Use `declare -xr` for exported constants
- Set constants at runtime if needed, but make them `readonly` immediately afterwards

## Constants

- Declare at the top of the file
- Use `readonly` for constants, `export` separately if needed:
  ```bash
  readonly MY_CONST='value'
  export MY_CONST
  ```

## Error messages

- All error messages must go to STDERR (`>&2`)
- Have an `err()` function for printing errors

## main function

- Scripts long enough to contain at least one other function must have a `main` function
- `main` should be the bottom-most function
- Last non-comment line in the file: `main "$@"`

## Aliases

- Never use aliases in scripts — use functions instead

## eval

- Avoid `eval` whenever possible

## SUID/SGID

- Never set SUID/SGID on shell scripts

## Wildcard expansion

- Use explicit path prefixes like `./*` instead of bare `*` to avoid issues with filenames starting with `-`

## Checking return values

- Always check return values of commands
- For pipes, capture `PIPESTATUS` immediately into an array if you need to inspect individual stages

## Consistency

- When modifying existing files, stay consistent with the existing style where the guide allows flexibility
- When creating new files, follow the guide strictly
