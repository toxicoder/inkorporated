---
description: Core coding standards and best practices
author: toxicoder
version: 2.0
globs: ["**/*.py", "**/*.js", "**/*.ts", "**/*.go", "**/*.rs", "**/*.proto"]
tags: ["coding-standard", "best-practices", "documentation"]
---

# Core Rules

## Use Style Guides

- Always leverage context7 before writing code to ensure you're following the latest practices.
- Always reference relevant style guides in the `docs/style_guides` directory.

**Example:**

```bash
# Before writing Python code, query context7
context7 query-docs --library "/python/docs" --query "PEP 8 best practices"
```

## Rich Docstrings and Typing

### File-Level Docstrings

Every file must begin with a detailed module docstring.

**Example (Python):**

```python
"""Module description explaining purpose and usage.

This module provides functionality for X. It is used in conjunction with Y
to achieve Z.

Example:
    from module import function
    result = function(arg1, arg2)
"""
```

### Function/Method Docstrings

All functions must have rich, detailed docstrings including:

- A one-line summary
- A description
- Params, Returns, Yields, Throws or related sections

**Example:**

```python
def process_data(data: dict, options: ProcessingOptions) -> ProcessedResult:
    """Process input data according to specified options.

    This function transforms raw input data into a structured format,
    applying validation and normalization as configured.

    Args:
        data: The raw input data to process.
        options: Configuration options controlling processing behavior.

    Returns:
        A ProcessedResult containing the transformed data and metadata.

    Raises:
        ValidationError: If input data fails validation checks.
        ProcessingError: If an error occurs during transformation.
    """
    pass
```

### Type Hints

All objects, variables, constants, params, returns, errors must be strongly typed or have type hints.

**Example (TypeScript):**

```typescript
interface Config {
  apiKey: string;
  timeout: number;
}

async function fetchConfig(config: Config): Promise<ConfigResult> {
  // Implementation
}
```

## Protocol Buffers

1. Ensure all protocol buffer files have a rich docstring.
2. Ensure every `message` has a detailed description.
3. Ensure every `field` has a detailed description.

**Example:**

```protobuf
// Request message for user authentication
message AuthenticateRequest {
  // The user's unique identifier
  string user_id = 1;

  // JWT token for authentication
  string token = 2;

  // Optional refresh token for session renewal
  optional string refresh_token = 3;
}
```

## Modular Code

Write code as modular and re-usable as possible. Always break code down into the smallest reasonable logical components leveraging public and private functions. Use clearly named variables to make code more reusable and readable.

**Example (Good):**

```python
def calculate_total(items: list[Item]) -> Decimal:
    """Calculate total price of all items."""
    return sum(calculate_item_total(item) for item in items)

def calculate_item_total(item: Item) -> Decimal:
    """Calculate total for a single item including tax."""
    subtotal = item.price * item.quantity
    tax = calculate_tax(subtotal, item.tax_rate)
    return subtotal + tax

def calculate_tax(amount: Decimal, rate: Decimal) -> Decimal:
    """Calculate tax amount."""
    return amount * rate
```

**Example (Bad - monolithic):**

```python
def calculate_total(items: list[Item]) -> Decimal:
    """Calculate total - does everything in one function."""
    total = Decimal("0")
    for item in items:
        subtotal = item.price * item.quantity
        tax = subtotal * item.tax_rate
        total += subtotal + tax
    return total
```

## Full Test Coverage

Write tests for ALL code you write, 100% test coverage is expected.

**Example (pytest):**

```python
def test_calculate_total_with_multiple_items():
    items = [
        Item(name="A", price=Decimal("10.00"), quantity=2, tax_rate=Decimal("0.10")),
        Item(name="B", price=Decimal("20.00"), quantity=1, tax_rate=Decimal("0.15")),
    ]
    result = calculate_total(items)
    assert result == Decimal("51.00")  # (20 + 2) + (20 + 3)
```

## Always Document

Always update or create relevant documentation when making any change.

**Documentation locations:**
| Change Type | Documentation Location |
|-------------|----------------------|
| New feature | `docs/guides/` and inline docstrings |
| API change | `docs/reference/` and type stubs |
| Architecture | `docs/architecture/` |
| Breaking change | Changelog and migration guide |

## Always Document

Always update or create relevant documentation when making any change.

**Documentation locations:**

| Change Type     | Documentation Location               |
| --------------- | ------------------------------------ |
| New feature     | `docs/guides/` and inline docstrings |
| API change      | `docs/reference/` and type stubs     |
| Architecture    | `docs/architecture/`                 |
| Breaking change | Changelog and migration guide        |
