# Lua Validation Library

A flexible validation library for Lua to validate various values and table structures.

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Basic Usage](#basic-usage)
  - [Validating Simple Data Types](#validating-simple-data-types)
  - [Validating Complex Data Types](#validating-complex-data-types)
- [Validation Definition Functions](#validation-definition-functions)
  - [`valid.literal`](#validliteral)
  - [`valid.number`](#validnumber)
  - [`valid.string`](#validstring)
  - [`valid.table`](#validtable)
  - [`valid.array`](#validarray)
  - [`valid.arrayof`](#validarrayof)
  - [`valid.map`](#validmap)
  - [`valid.mapof`](#validmapof)
- [Error Handling and Invalid Propagation](#error-handling-and-invalid-propagation)
- [Running Tests](#running-tests)
- [Contributing](#contributing)
- [License](#license)

## Features

- Validate literals, numbers, strings, and tables (arrays and maps).
- Customizable validation functions.
- Detailed error reporting with paths to invalid keys or indices.
- Nested validations for complex table structures.

## Installation

Copy the `valid.lua` file to a directory in your `LUA_PATH`.

## Basic Usage

### Validating Simple Data Types

```lua
local valid = require "valid"

local is_valid = valid.literal("abc")("abc")
assert(is_valid)  -- true

local is_valid = valid.number {min = 0, max = 10}(5)
assert(is_valid)  -- true

local is_valid = valid.string {pattern = "%d%d%d"}("abc")
assert(not is_valid)  -- false, not numerical digits

local is_valid = valid.string {pattern = "%d%d%d"}("123")
assert(is_valid)  -- true
```

### Validating Complex Data Types

```lua
local valid = require "valid"

local valid_contact = valid.map {
    required = {"email"},
    table = {
        email = valid.string {pattern = ".+@.+%..+"}, -- A very naive email pattern
        phone = valid.string {pattern = "%d%d%d%-%d%d%d%-%d%d%d%d"},
        address = valid.map {
            required = {"country", "zipcode"},
            table = {
                street = valid.string {minlen = 5, maxlen = 50},
                city = valid.string {minlen = 2, maxlen = 30},
                zipcode = valid.string {pattern = "%d%d%d%d%d"},
                country = "USA" -- shorthand for valid.literal("USA")
            }
        }
    }
}

local contact_data = {
    email = "john.doe@example.com",
    phone = "123-456-7890",
    address = {
        -- street and city aren't required
        country = "USA", 
        zipcode = "12345"
    }
}

local is_valid = valid_contact(contact_data)
assert(is_valid)  -- true
```

## Validation Definition Functions

### `valid.literal`

Validates that a value matches a specific literal.

#### Usage

```lua
local valid = require "valid"

local is_valid = valid.literal("abc")("abc")
assert(is_valid)  -- true

local is_valid = valid.literal("abc")("123")
assert(not is_valid)  -- false
```

### `valid.number`

Validates that a value is a number within an optional range.

Note: Values are not coerced to numbers by e.g. `tonumber()`.  The input value itself must already be a number or validation will fail.

#### Usage

```lua
local valid = require "valid"

local is_valid = valid.number {min = 0, max = 10}(5)
assert(is_valid)  -- true

local is_valid = valid.number {min = 0, max = 1}(5)
assert(not is_valid)  -- false, not in range

local is_valid = valid.number {min = -50, max = 50}(-1)
assert(is_valid)  -- true

local is_valid = valid.number {min = -5.5, max = 0}(-1.1111)
assert(is_valid)  -- true

local is_valid = valid.number {min = 0, max = 10}("8")
assert(not is_valid)  -- false, not a number
```

#### Parameters

* `opts` (optional): Table of options.
    * `min`: The minimum allowable value (inclusive).
    * `max`: The maximum allowable value (inclusive).
    * `func`: A custom validation function to call after the number check.

### `valid.string`

Validates that a value is a string with optional length and pattern constraints.

Note: Values are not coerced to strings by e.g. `tostring()`.  The input value itself must already be a string or validation will fail.

#### Usage

```lua
local valid = require "valid"

local is_valid = valid.string {minlen = 3, maxlen = 5}("hello")
assert(is_valid)  -- true

local is_valid = valid.string {minlen = 6, maxlen = 10}("hello")
assert(not is_valid)  -- false, too short

local is_valid = valid.string {pattern = "%d%d%d"}("123")
assert(is_valid)  -- true

local is_valid = valid.string {pattern = "%d%d%d"}("abc")
assert(not is_valid)  -- false, pattern does not match

local is_valid = valid.string {minlen = 2, maxlen = 4, pattern = "a+"}("aaa")
assert(is_valid)  -- true
```

#### Parameters

* `opts` (optional): Table of options.
    * `minlen`: The minimum allowable length of the string (inclusive).
    * `maxlen`: The maximum allowable length of the string (inclusive).
    * `func`: A custom validation function to call after the string check.

### `valid.table`

Validates that a value is a table, with optional constraints for arrays and maps.

#### Usage

```lua
local valid = require "valid"

local valid_person = valid.table {
    required = {"name", "age"},
    table = {
        name = valid.string {minlen = 3, maxlen = 50},
        age = valid.number {min = 0, max = 120},
        email = valid.string {pattern = ".+@.+%..+"}, -- A very naive email pattern
        phone = valid.string {
            pattern = "%d%d%d%-%d%d%d%-%d%d%d%d",
            func = function(val)
                if #val ~= 12 then
                    return false, "invalid phone format", val
                end

                return true, val
            end
        }
    }
}

local person_data = {
    name = "John Doe",
    age = 35,
    email = "john.doe@example.com",
    phone = "123-456-7890"
}

local is_valid = valid_person(person_data)
assert(is_valid)  -- true

local invalid_person_data = {
    name = "Jo",
    age = 150,
    email = "john.doeexample.com",
    phone = "123-4567-890"
}

local is_valid = valid_person(invalid_person_data)
assert(not is_valid)  -- false, multiple validation errors
```

#### Parameters

* `opts` (optional): Table of options.
    * `array`: Set to `true` if the table should be validated as an array.
    * `map`: Set to `true` if the table should be validated as a map.
    * `empty`: Set to `true` to allow empty tables.
    * `required`: An optional list of required keys for maps.
    * `func`: A custom validation function to call after the table check.
    * `table`: A nested table definition for validating nested tables.

### `valid.array`

A shorthand for [`valid.table`](#validtable) with `opts.array` set to `true`.

#### Parameters

* `opts` (optional): Table of options.
    * `empty`: Set to `true` to allow empty tables.
    * `func`: A custom validation function to call after the table check.
    * `table`: A nested table definition for validating nested tables.

### `valid.arrayof`

Validates that a value is an array where each element matches a given definition.

#### Usage

```lua
local valid = require "valid"

-- An array where each element is a number within the range 1 to 10
local valid_numbers = valid.arrayof(valid.number {min = 1, max = 10})

local numbers_data = {1, 2, 3, 4, 5}

local is_valid = valid_numbers(numbers_data)
assert(is_valid)  -- true

local invalid_numbers_data = {1, 2, 11, 4, 5}

local is_valid = valid_numbers(invalid_numbers_data)
assert(not is_valid)  -- false, 11 is not within the range 1 to 10

-- An array where each element is a valid string
local valid_strings = valid.arrayof(valid.string {minlen = 2, maxlen = 5})

local strings_data = {"hi", "hello", "hey"}

local is_valid = valid_strings(strings_data)
assert(is_valid)  -- true

local invalid_strings_data = {"hi", "hello", "thisiswaytoolong"}

local is_valid = valid_strings(invalid_strings_data)
assert(not is_valid)  -- false, too long
```

#### Parameters

* `deffunc` (required): The definition function for the array elements.
* `opts` (optional): Table of options.
    * `minlen`: The minimum allowable length of the array, If `0` then sets `empty = true`.
    * `maxlen`: The maximum allowable length of the array.
    * `empty`: Set to `true` to allow empty arrays.  If `true` thensets `minlen = 0`.
    * `func`: A custom validation function to call after the array check.


### `valid.map`

A shorthand for [`valid.table`](#validtable) with `opts.map` set to `true`.

#### Parameters

* `opts` (optional): Table of options.
    * `empty`: Set to `true` to allow empty tables.
    * `required`: An optional list of required keys.
    * `func`: A custom validation function to call after the table check.
    * `table`: A nested table definition for validating nested tables.

### `valid.mapof`

#### Usage

```lua
local valid = require "valid"

-- A map where keys are strings and values are numbers within the range 1 to 10
local valid_string_number_map = valid.mapof({
    valid.string(),
    valid.number {min = 1, max = 10}
})

local map_data = {
    one = 1,
    two = 2,
    three = 3
}

local is_valid = valid_string_number_map(map_data)
assert(is_valid)  -- true

local invalid_map_data = {
    one = 1,
    two = 2,
    three = 11
}

local is_valid = valid_string_number_map(invalid_map_data)
assert(not is_valid)  -- false, 11 is not within the range 1 to 10

-- Define a map where keys are strings and values are valid person objects
local valid_person = valid.map {
    required = {"name"},
    table = {
        name = valid.string {minlen = 3},
        age = valid.number {min = 0}
    }
}

local valid_people_map = valid.mapof({valid.string, valid_person})

local people_data = {
    alice = {name = "Alice", age = 30},
    bob = {name = "Bob", age = 25}
}

local is_valid = valid_people_map(people_data)
assert(is_valid)  -- true

local invalid_people_data = {
    alice = {name = "Alice", age = 30},
    bob = {age = 25}  -- Missing required field "name"
}

local is_valid = valid_people_map(invalid_people_data)
assert(not is_valid)  -- false, "name" is required for "bob"
```

#### Parameters

* `deffuncs` (required): A table containing two definitions, one for the keys and one for the values.
* `opts` (optional): Table of options.
    * `empty`:  Set to `true` to allow empty maps.
    * `func`: A table containing two custom validation functions, one for the keys and one for the values.

## Error Handling and Invalid Propagation

The library provides detailed error information when validation fails. When `is_valid` is `false`, additional values are provided to help identify the nature of the validation failure:

* `err`: Describes the type of validation error that occurred.
* `badval`: The value that caused the validation to fail.
* `path`: The path to the invalid key or index within the data structure.

These additional values can be used to pinpoint exactly where and why the validation failed.

### Example

```lua
local valid = require "valid"

local valid_contact = valid.map {
    required = {"email"},
    table = {
        email = valid.string {pattern = ".+@.+%..+"},  -- A very naive email pattern
        phone = valid.string {pattern = "%d%d%d%-%d%d%d%-%d%d%d%d"},
    }
}

local valid_person = valid.map {
    required = {"name", "contact"},
    table = {
        name = valid.string {minlen = 3, maxlen = 50},
        contact = valid_contact
    }
}

local person_data = {
    name = "John Doe",
    contact = {
        email = "invalid-email.com",  -- Invalid email
        phone = "123-456-7890"
    }
}

local is_valid, val_or_err, badval_or_nil, path = valid_person(person_data)

print("is_valid:", is_valid) -- false
print("val_or_err:", val_or_err) -- "pattern"
print("badval_or_nil:", badval_or_nil) -- invalid-email.com

-- path is a table like {"contact", {"email"}}
print("path:", path[1], path[2][1]) -- "contact" "email"
```

```
is_valid:      false
val_or_err:    pattern
badval_or_nil: invalid-email.com
path:          contact email
```

## Contributing

Contributions are welcome! If you have any ideas, suggestions, or bug reports, please open an issue on this GitHub repository. If you would like to contribute code, please fork the repository and submit a pull request. Make sure to follow the existing code style and include tests for any new features or bug fixes.

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.
