return {
    settings = {
        Lua = {
            hint = {
                arrayIndex = "Disable",
                paramName = "Literal",
                paramType = true,
                setType = false,
                await = true,
                semicolon = "Disable",
            },
            diagnostics = {
                globals = { "vim", "Snacks" }
            }
        }
    }
}
