DEBUG=true
function love.conf(t)
    t.console=DEBUG
    t.title = "flowRT"
    t.window.width = 901
    t.window.height = 396
    t.window.resizable = true
    t.window.msaa = 0
    t.window.borderless=true
    t.window.vsync = 0
end