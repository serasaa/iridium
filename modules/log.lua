---@class log
local log={}
local immediateUI=require("ui.immediate")
local logString=""
function log.log(...)
    local strings={...}
    local numStrings=select("#", ...)
    if numStrings==1 then
        logString="\n"..tostring(strings[1])..logString
    elseif numStrings>1 then
        local finalString=""
        for i,v in ipairs(strings) do
            if i~=numStrings then
                finalString=finalString.. tostring(v)..", "
            elseif i==numStrings then
                finalString=finalString.. tostring(v)
            end
        end
        logString="\n"..finalString..logString
    end
end

function log.draw()
    immediateUI.debugText(logString)
end

return log