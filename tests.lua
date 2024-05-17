local valid = require "valid"
local busted = require "busted"

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
            tags = valid.arrayof(valid.string {minlen = 1}, {empty = true})
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
                key = nil
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
                key = nil
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
                key = nil
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
                key = nil
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
                key = {"city"}
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
                key = {"contact", {"email"}}
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
                key = {"contact", {"phone"}}
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
                key = {"price"}
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
                key = {"products", {2, {"price"}}}
            }
        }
    }

    for _, test in ipairs(tests) do
        it(test.description, function()
            local is_valid, val_or_err, badval_or_nil, key = test.definition(test.data)

            assert.is_equal(test.expected.is_valid, is_valid)

            if type(val_or_err) == "table" then
                assert.same(test.expected.val_or_err, val_or_err)
            else
                assert.is_equal(test.expected.val_or_err, val_or_err)
            end

            assert.is_equal(test.expected.badval_or_nil, badval_or_nil)

            if type(key) == "table" then
                assert.same(test.expected.key, key)
            else
                assert.is_equal(test.expected.key, key)
            end
        end)
    end
end)
