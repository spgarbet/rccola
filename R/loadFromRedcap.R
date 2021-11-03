# rccola load data from RedCap, keep API_KEYs safe
# Copyright (C) 2021 Shawn Garbett
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

split_path <- function(path) {
    rev(setdiff(strsplit(path,"/|\\\\")[[1]], ""))
}

#' @importFrom redcapAPI redcapConnection
#' @importFrom redcapAPI exportRecords
readRC <- function(url, key, ...)
{
  con <- redcapAPI::redcapConnection(url=url, token=key)
  args <- c(rcon = con, list(...))
  if(!('factors' %in% names(args))) args$factors <- TRUE
  if(!('labels' %in% names(args))) args$labels <- TRUE
  do.call(redcapAPI::exportRecords, args)
}

#' Load data requested into current environment from RedCap
#'
#' The first thing it does is check for a yaml config file of
#' the same name as the current directory with a .yml extension
#' one level above. This is intended for production environments
#' where the API_KEY must be stored in a file. If this yaml exists, then it expects this file
#' to contain `apiUrl` and `apiKeys`. `apiUrl` should be a
#' string with the URL of the Redcap instance. `apiKeys` should
#' be a list of variable name keys with values that are their
#' actual RedCap API_KEY.
#'
#' Next it will use an api environment in memory to keep api_keys.
#' If one is knitting with parameters, it will request and store these
#' keys in memory. Otherwise it will request the user enter
#' each key using getPass and store it in memory.
#'
#' IMPORTANT: Make sure that R is set to NEVER save workspace to .RData
#' as this is the equivalent of writing the API_KEY to a local
#' file in clear text.
#'
#' @param variables A list of strings that define the variables to fill with RedCap data
#' @param apiUrl The api interface to the RedCap instance to use. defaults to the Vanderbilt instance.
#' @param envir The target environment for the data. Defaults to .Global
#' @param keyring Potential keyring, not used by default.
#' @param \dots Additional arguments passed to \code{\link[redcapAPI]{exportRecords}}.
#' @return Nothing
#'
#' @examples
#' \donttest{loadFromRedcap(data)}
#'
#' @importFrom getPass getPass
#' @importFrom yaml read_yaml
#'
#' @export
#'
loadFromRedcap <- function(variables,
                           apiUrl="https://redcap.vanderbilt.edu/api/",
                           envir=NULL,
                           keyring=NULL, ...)
{
  # Use the global environment for variable storage unless one was specified
  dest <- if(is.null(envir)) globalenv() else envir

  # If the data exists, clear from memory
  for(i in variables) if(exists(i, envir=dest)) rm(i, envir=dest)

  # Use config if it exists
  config_file <- file.path("..", paste0(split_path(getwd())[1],".yml"))
  if(file.exists(config_file))
  {
    config <- read_yaml(config_file)

    tryCatch(
      for(i in variables)
        assign(i, readRC(config$apiURL, config$apiKeys[[i]], ...), envir=dest),
      error=function(e) stop(e)
    )

    return(invisible())
  }

  # Create an environment to house API_KEYS locally
  if(!exists("api")) api <- new.env()

  # For each dataset requested
  for(i in variables)
  {
    # If the API_KEY doesn't exist go look for it
    if(!exists(i, envir=api, inherits=FALSE) || is.null(api[[i]]) || is.na(api[[i]]) || api[[i]]=='')
    {
      # Pull from knit with params if that exists
      if(exists("params") && !is.null(params[[i]]) && params[[i]] != "")
      {
        # Pull from Rmarkdown parameters
        api[[i]] <- params[[i]]
      } else # Ask the user for it
      {
        api[[i]] <- getPass::getPass(msg=paste("Please enter RedCap API_KEY for", i))
      }
    }

    tryCatch(
      assign(i, readRC(apiUrl, api[[i]]), envir=dest),
      error = function(e)
      {
        rm(i, envir = api)
        stop(e)
      }
    )
  }
  return(invisible())
}
