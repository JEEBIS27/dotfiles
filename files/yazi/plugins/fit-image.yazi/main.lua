--- @since 26.9.1
-- Fit images to the preview area, including upscaling small originals.
local M = {}
function M:peek(job)
  if job.area.w == 0 or job.area.h == 0 then return end
  local cw, ch = rt.term.cell_size()
  local width = math.min(rt.preview.max_width, math.floor(job.area.w * (cw or 1)))
  local height = math.min(rt.preview.max_height, math.floor(job.area.h * (ch or 1)))
  if not cw then width, height = rt.preview.max_width, rt.preview.max_height end
  local tmp = os.tmpname()
  local output, err = Command("magick"):arg {
    tostring(job.file.path) .. "[0]", "-auto-orient", "-strip",
    "-resize", string.format("%dx%d", width, height), "PNG:" .. tmp,
  }:output()
  if not output then
    err = "Failed to start magick: " .. tostring(err)
  elseif not output.status.success then
    err = output.stderr
  else
    ya.sleep(rt.preview.image_delay / 1000)
    local shown
    shown, err = ya.image_show(Url(tmp), job.area)
  end
  os.remove(tmp)
  ya.preview_widget(job, err)
end
function M:seek() end
function M:spot(job) require("image"):spot(job) end
return M
