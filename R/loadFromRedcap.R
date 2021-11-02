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

# Turn a passed pformat into a function (or leave alone)

split_path <- function(path) {
    rev(setdiff(strsplit(path,"/|\\\\")[[1]], ""))
}

readRC <- function(url, key)
{
  exportRecords(redcapConnection(url=url, token=key), factors = TRUE, labels = TRUE)
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
#'
#' @return Nothing
#'
#' @example
#' \donttest{loadFromRedcap(data)}
#'
#' @export
#'
loadFromRedcap <- function(variables, apiUrl="https://redcap.vanderbilt.edu/api/")
{
  p <- parent.env(environment())

  # If the data exists, clear from memory
  for(i in variables) if(exists(i)) rm(i, inherits=TRUE)

  # Use config if it exists
  config_file <- file.path("..", paste0(split_path(getwd())[1],".yml"))
  if(file.exists(config_file))
  {
    config <- read_yaml(config_file)

    tryCatch(
      for(i in variables)
        assign(i, readRC(config$apiURL, config$apiKeys[[i]]), envir=p),
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
    if(!exists(i, envir=api))
    {
      # Pull from knit with params if that exists
      if(exists("params") && !is.null(params[[i]]) && params[[i]] != "")
      {
        # Pull from Rmarkdown parameters
        api[[i]] <- params[[i]]
      } else # Ask the user for it
      {
        api[[i]] <- getPass(msg=paste("Please enter RedCap API_KEY for", i))
      }
    }

    rcon <- redcapConnection(url=apiUrl, token=api[[i]])
    tryCatch(
      assign(i, exportRecords(rcon, factors = TRUE, labels = TRUE), envir=p),
      error = function(e)
      {
        rm(i, envir = api)
        stop(e)
      }
    )
  }
  return(invisible())
}
