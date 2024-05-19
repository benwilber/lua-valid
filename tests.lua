require "busted"
local valid = require "valid"

local ptable
ptable = function(tbl, indent) -- luacheck: no unused
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end

    indent = indent or 0
    local s = string.rep(" ", indent) .. "{\n"

    indent = indent + 2

    for k, v in pairs(tbl) do
        local fmt = string.rep(" ", indent) .. "[" .. tostring(k) .. "] = "

        if type(v) == "table" then
            s = s .. fmt .. ptable(v, indent)
        else
            s = s .. fmt .. tostring(v) .. ",\n"
        end
    end

    return s .. string.rep(" ", indent - 2) .. "},\n"
end

describe("Validation Library Tests", function()

    local valid_contact = valid.map {
        required = {"contact"},
        table = {
            id = valid.literal("abc"),
            name = valid.string {minlen = 3, maxlen = 20},
            age = valid.number {min = 0, max = 120},
            contact = valid.map {
                required = {"email"},
                table = {
                    email = valid.string {pattern = ".+@.+%..+"},
                    phone = valid.string {pattern = "%d%d%d%-%d%d%d%-%d%d%d%d"}
                }
            },
            friend_ids = valid.arrayof(valid.number(), {empty = true})
        }
    }

    local valid_address = valid.map {
        required = {"street", "city"},
        table = {
            street = valid.string {minlen = 5, maxlen = 50},
            city = valid.string {minlen = 2, maxlen = 30},
            zipcode = valid.string {pattern = "%d%d%d%d%d"},
            country = valid.literal("USA")
        }
    }

    local valid_product = valid.map {
        required = {"id", "name", "price"},
        table = {
            id = valid.string {pattern = "%w+"},
            name = valid.string {minlen = 3, maxlen = 100},
            price = valid.number {min = 0.01},
            tags = valid.arrayof(valid.string {minlen = 1}, {empty = true, unique = true})
        }
    }

    local valid_order = valid.map {
        required = {"order_id", "products"},
        table = {
            order_id = valid.string {pattern = "%w+"},
            products = valid.arrayof(valid_product),
            shipping_address = valid_address,
            billing_address = valid_address
        }
    }

    local tests = {
        -- Valid contact data
        {
            description = "Valid contact data",
            definition = valid_contact,
            data = {
                id = "abc",
                name = "John Doe",
                age = 35,
                contact = {
                    email = "john.doe@example.com",
                    phone = "123-456-7890"
                },
                friend_ids = {1, 2, 3}
            },
            expected = {
                is_valid = true,
                val_or_err = {
                    id = "abc",
                    name = "John Doe",
                    age = 35,
                    contact = {
                        email = "john.doe@example.com",
                        phone = "123-456-7890"
                    },
                    friend_ids = {1, 2, 3}
                },
                badval_or_nil = nil,
                path_or_nil = nil
            }
        },

        -- Valid address data
        {
            description = "Valid address data",
            definition = valid_address,
            data = {
                street = "123 Main St",
                city = "New York",
                zipcode = "12345",
                country = "USA"
            },
            expected = {
                is_valid = true,
                val_or_err = {
                    street = "123 Main St",
                    city = "New York",
                    zipcode = "12345",
                    country = "USA"
                },
                badval_or_nil = nil,
                path_or_nil = nil
            }
        },

        -- Valid product data
        {
            description = "Valid product data",
            definition = valid_product,
            data = {
                id = "p001",
                name = "Widget",
                price = 19.99,
                tags = {"sale", "new"}
            },
            expected = {
                is_valid = true,
                val_or_err = {
                    id = "p001",
                    name = "Widget",
                    price = 19.99,
                    tags = {"sale", "new"}
                },
                badval_or_nil = nil,
                path_or_nil = nil
            }
        },

        -- Invalid product data (unique tags)
        {
            description = "Invalid product data (unique tags)",
            definition = valid_product,
            data = {
                id = "p001",
                name = "Widget",
                price = 19.99,
                tags = {"sale", "new", "new"}
            },
            expected = {
                is_valid = false,
                val_or_err = "unique",
                badval_or_nil = "new",
                path_or_nil = {"tags", {2, 3}}
            }
        },

        -- Valid order data
        {
            description = "Valid order data",
            definition = valid_order,
            data = {
                order_id = "ord001",
                products = {
                    {
                        id = "p001",
                        name = "Widget",
                        price = 19.99,
                        tags = {"sale", "new"}
                    },
                    {
                        id = "p002",
                        name = "Gadget",
                        price = 29.99,
                        tags = {"popular"}
                    }
                },
                shipping_address = {
                    street = "123 Main St",
                    city = "New York",
                    zipcode = "12345",
                    country = "USA"
                },
                billing_address = {
                    street = "456 Elm St",
                    city = "Los Angeles",
                    zipcode = "67890",
                    country = "USA"
                }
            },
            expected = {
                is_valid = true,
                val_or_err = {
                    order_id = "ord001",
                    products = {
                        {
                            id = "p001",
                            name = "Widget",
                            price = 19.99,
                            tags = {"sale", "new"}
                        },
                        {
                            id = "p002",
                            name = "Gadget",
                            price = 29.99,
                            tags = {"popular"}
                        }
                    },
                    shipping_address = {
                        street = "123 Main St",
                        city = "New York",
                        zipcode = "12345",
                        country = "USA"
                    },
                    billing_address = {
                        street = "456 Elm St",
                        city = "Los Angeles",
                        zipcode = "67890",
                        country = "USA"
                    }
                },
                badval_or_nil = nil,
                path_or_nil = nil
            }
        },

        -- Missing required field in address
        {
            description = "Missing required field in address",
            definition = valid_address,
            data = {
                street = "123 Main St",
                zipcode = "12345",
                country = "USA"
            },
            expected = {
                is_valid = false,
                val_or_err = "required",
                badval_or_nil = "city",
                path_or_nil = {"city"}
            }
        },

        -- Invalid email pattern in contact
        {
            description = "Invalid email pattern in contact",
            definition = valid_contact,
            data = {
                id = "abc",
                name = "John Doe",
                age = 35,
                contact = {
                    email = "john.doeexample.com",
                    phone = "123-456-7890"
                },
                friend_ids = {1, 2, 3}
            },
            expected = {
                is_valid = false,
                val_or_err = "pattern",
                badval_or_nil = "john.doeexample.com",
                path_or_nil = {"contact", {"email"}}
            }
        },

        -- Invalid phone pattern in contact
        {
            description = "Invalid phone pattern in contact",
            definition = valid_contact,
            data = {
                id = "abc",
                name = "John Doe",
                age = 35,
                contact = {
                    email = "john.doe@example.com",
                    phone = "123-4567890"
                },
                friend_ids = {1, 2, 3}
            },
            expected = {
                is_valid = false,
                val_or_err = "pattern",
                badval_or_nil = "123-4567890",
                path_or_nil = {"contact", {"phone"}}
            }
        },

        -- Invalid product price (too low)
        {
            description = "Invalid product price (too low)",
            definition = valid_product,
            data = {
                id = "p001",
                name = "Widget",
                price = 0,
                tags = {"sale", "new"}
            },
            expected = {
                is_valid = false,
                val_or_err = "min",
                badval_or_nil = 0,
                path_or_nil = {"price"}
            }
        },

        -- Invalid order data (invalid product)
        {
            description = "Invalid order data (invalid product)",
            definition = valid_order,
            data = {
                order_id = "ord001",
                products = {
                    {
                        id = "p001",
                        name = "Widget",
                        price = 19.99,
                        tags = {"sale", "new"}
                    },
                    {
                        id = "p002",
                        name = "Gadget",
                        price = -5.00,
                        tags = {"popular"}
                    }
                },
                shipping_address = {
                    street = "123 Main St",
                    city = "New York",
                    zipcode = "12345",
                    country = "USA"
                },
                billing_address = {
                    street = "456 Elm St",
                    city = "Los Angeles",
                    zipcode = "67890",
                    country = "USA"
                }
            },
            expected = {
                is_valid = false,
                val_or_err = "min",
                badval_or_nil = -5.00,
                path_or_nil = {"products", {2, {"price"}}}
            }
        },
        {
            description = "Deeply nested",
            definition = valid.map {
                table = {
                    categories = valid.arrayof(
                        valid.map {
                            table = {
                                widgets = valid.arrayof(
                                    valid.map {
                                        table = {
                                            tags = valid.map {
                                                table = {
                                                    name = valid.string()
                                                }
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    )
                }
            },
            data = {
                categories = {
                    {
                        widgets = {
                            {
                                tags = {
                                    name = 12345
                                }
                            }
                        }
                    }
                }
            },
            expected = {
                is_valid = false,
                val_or_err = "string",
                badval_or_nil = 12345,
                path_or_nil = {
                    "categories",
                    {
                        1,
                        {
                            "widgets",
                            {
                                1,
                                {
                                    "tags",
                                    {
                                        "name"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    for _, test in ipairs(tests) do
        it(test.description, function()
            local is_valid, val_or_err, badval_or_nil, path_or_nil = test.definition(test.data)

            -- print(is_valid, val_or_err, ptable(badval_or_nil), ptable(path_or_nil))

            assert.is_equal(test.expected.is_valid, is_valid)

            if type(val_or_err) == "table" then
                assert.same(test.expected.val_or_err, val_or_err)
            else
                assert.is_equal(test.expected.val_or_err, val_or_err)
            end

            assert.is_equal(test.expected.badval_or_nil, badval_or_nil)

            if type(path_or_nil) == "table" then
                assert.same(test.expected.path_or_nil, path_or_nil)
            else
                assert.is_equal(test.expected.path_or_nil, path_or_nil)
            end
        end)
    end
end)
