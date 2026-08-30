local gInit={
    init=function()
        -- setting them globals lmao
        editorSelectedLineThickness=3
        
        networkingReasons={}
        table.insert(networkingReasons,0,"quit")
        table.insert(networkingReasons,1,"timed out")
    end
}

return gInit