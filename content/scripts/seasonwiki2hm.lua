local URL = "https://cuilian-wiki.pages.dev/"
local M = {}

function M.Open()
    -- Pass false to the desktop game's URL handler to bypass the Steam overlay.
    VisitURL(URL, false)
end

function M.InstallConsole(screen)
    local Run = screen.Run
    function screen:Run(...)
        -- Handle the shortcut before the console chooses local or remote execution.
        if self.console_edit:GetString():match("^%s*/wiki%s*$") then
            return M.Open()
        end
        return Run(self, ...)
    end
end

return M
