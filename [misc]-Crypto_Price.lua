local http = require("gamesense/http") or error("Download http library", 2)

local cryptos = {
    { name = "bitcoin",  color = "\aCC9900FF", spacing = 4 }, --hardcoded spacing for aligned text
    { name = "ethereum", color = "\a716b94FF", spacing = 1 },
    { name = "tether",   color = "\a26A17BFF", spacing = 5 },
    { name = "litecoin", color = "\aB8B8B8FF", spacing = 3 }
}

local char = {
    ["USD"] = "$",
    ["EUR"] = "€",
    ["GBP"] = "£",
    ["SEK"] = "kr",
}
local menu = {
    currency = ui.new_combobox("LUA", "B", " \a21a072FF•\aFFFFFFFF Crypto Prices", "USD", "EUR", "GBP", "SEK"),
    ui.new_label("LUA", "B", " \a21a072FF_________________________________"),
}

local crypto_names = {}
for _, crypto in pairs(cryptos) do
    table.insert(crypto_names, crypto.name)
    menu[crypto.name] = ui.new_label("LUA", "B", " ")
    crypto.init_value = {}
end

menu.warning = ui.new_label("LUA", "B", "\ae96162FFUser has sent too many API requests")
ui.set_visible(menu.warning, false)

local function add_commas(n)
    local b, a = tostring(n):match("([^.]*)%.?(.*)")
    b = b:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return a ~= "" and b .. "." .. a or b
end

local crypto_string = table.concat(crypto_names, ",")
local function refresh()
    http.get("https://api.coingecko.com/api/v3/simple/price?ids=" .. crypto_string .. "&vs_currencies=gbp,usd,eur,sek", function(success, response)
        ui.set_visible(menu.warning, response.status == 429) -- rate limit
        if not success or response.status ~= 200 then
            return
        end

        local res = json.parse(response.body)
        if res then
            local selected_currency = ui.get(menu.currency)
            for _, crypto in ipairs(cryptos) do
                crypto.value = res[crypto.name][selected_currency:lower()]

                for currency, _ in pairs(char) do
                    if not crypto.init_value[currency] then
                        crypto.init_value[currency] = res[crypto.name][currency:lower()]
                    end
                end

                local change_value = ((crypto.value - crypto.init_value[selected_currency]) / crypto.init_value[selected_currency]) * 100
                local change = string.format("%+.2f%%", change_value)
                local change_color = change_value >= 0

                ui.set(menu[crypto.name], ("  %s%s: %s\aFFFFFFFF%s%s  (%s%s\aFFFFFFFF)"):format(
                    crypto.color,
                    crypto.name,
                    "\aFFFFFF00" .. string.rep("J", crypto.spacing), --scuffed menu alignement
                    add_commas(crypto.value),
                    char[selected_currency],
                    change_color and "\a21a072FF" or "\ae96162FF",
                    change
                ))
            end
        end
    end)
    client.delay_call(5, refresh) --5 second delay too fast refreshes can cause rate limit by api
end
refresh()
