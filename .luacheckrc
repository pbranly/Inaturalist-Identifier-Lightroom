-- .luacheckrc

-- Indique à Luacheck que certaines variables globales sont fournies par Lightroom
globals = {
  "import",
  "LOC",
  "_PLUGIN",        -- <- Lightroom plugin global
  "LrApplication",
  "LrDialogs",
  "LrTasks",
  "LrView",
  "LrLogger",
  "LrDate",
  "LrHttp",
  "LrPathUtils",
  "LrFunctionContext",
  "LrBinding",
  "LrColor",
  "LrFileUtils",
}
