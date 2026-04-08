# Core Rules

## Use Style Guides

- Always leverage context7 before writing code to ensure you're following the latest practices.
- Always reference relevant style guides in the `docs/style_guides` directory.

## Rich Docstrings and Typing

1. Ensure all files contain a detailed file level docstring.
2. Ensure all variables, constants, etc have detailed docstrings.
3. Ensure all functions have rich detailed docstrings including:
   - A one line summary.
   - A description.
   - Params, Returns, Yields, Throws or related sections.
4. Ensure all objects, variables, constants, params, returns, errors, etc
   are all always strongly typed or have type hints.

## Protocol Buffers

1. Ensure all protocol buffer files have a rich docstring.
2. Ensure every `message` has a detailed description.
3. Ensure every `field` has a detailed description.

## Modular Code

Write code as modular and re-usable as possible. Always break code down into the
smallest reasonable logical components leverage public and private functions.
Use clearly named variables to make code more reusable and readable.

## Full Test Coverage

Write tests for ALL code you write, 100% test coverage is expected.

## Always Document

Always update or create relevant documentation when making any change.
