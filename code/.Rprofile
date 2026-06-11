# Activate renv from the project root (one level up from code/)
local({
  path <- getwd()
  while (nchar(path) > 3) {
    activate <- file.path(path, "renv", "activate.R")
    if (file.exists(activate)) {
      source(activate)
      break
    }
    path <- dirname(path)
  }
})
