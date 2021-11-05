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
  redcapAPI::exportRecords(redcapAPI::redcapConnection(url=url, token=key), ...)
}

# Check if key is in package environment, aka memory
key_saved <- function(envir, key)
{
  exists(key, envir=envir, inherits=FALSE) &&
  !is.null(envir[[key]])                   &&
  !is.na(envir[[key]])                     &&
  !envir[[key]]==''
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
#' @param forms A list of forms. Keys are the variable(api_key), each key can contain a vector of forms.
#'              The output variable is now the <variable>.<form>
#' @param \dots Additional arguments passed to \code{\link[redcapAPI]{exportRecords}}.
#' @return Nothing
#'
#' @examples
#' \donttest{loadFromRedcap(data)}
#'
#' @importFrom getPass getPass
#' @importFrom yaml read_yaml
#' @importFrom keyring key_get
#' @importFrom keyring key_list
#' @importFrom keyring key_set_with_value
#' @importFrom keyring keyring_create
#' @importFrom keyring keyring_list
#'
#' @export
#'
loadFromRedcap <- function(variables,
                           apiUrl="https://redcap.vanderbilt.edu/api/",
                           envir=NULL,
                           keyring=NULL,
                           forms=NULL,
                           ...)
{
  # Use the global environment for variable storage unless one was specified
  dest <- if(is.null(envir)) globalenv() else envir

  # If the data exists, clear from memory
  for(i in variables)
  {
    if(is.null(forms) || !(i %in% names(forms)))
    {
      if(exists(i, envir=dest, inherits=FALSE)) rm(i, envir=dest)
    } else
    {
      for(j in forms[[i]])
      {
        v <- paste0(i, ".", j)
        if(exists(v, envir=dest, inherits=FALSE)) rm(list=v, envir=dest)
      }
    }
  }

  # Use config if it exists
  config_file <- file.path("..", paste0(split_path(getwd())[1],".yml"))
  if(file.exists(config_file))
  {
    config <- read_yaml(config_file)

    tryCatch(
      for(i in variables)
      {
        if(is.null(forms) || !(i %in% names(forms)))
        {
          assign(i, readRC(config$apiURL, config$apiKeys[[i]],...), envir=dest)
        } else
        {
          for(j in forms[[i]])
          {
            assign(paste0(i,".",j), readRC(config$apiURL, config$apiKeys[[i]],forms=j...), envir=dest)
          }
        }
      },
      error=function(e) stop(e)
    )

    return(invisible())
  }

  # Create an environment to house API_KEYS locally
  if(!exists("apiKeyStore", inherits=FALSE)) apiKeyStore <- new.env()

  # Create keyring if it doesn't exist
  if(!is.null(keyring) &&
     !(keyring  %in% (keyring::keyring_list()[,1]))
    )
  {
    keyring::keyring_create(keyring)
  }

  # For each dataset requested
  for(i in variables)
  {
    # If the API_KEY doesn't exist go look for it

    # Does it exist in a secret keyring, use that
    if(!key_saved(apiKeyStore, i))
    {
      if(!is.null(keyring) &&
         keyring %in% (keyring::keyring_list()[,1]) &&
         i %in% keyring::key_list("rccola", keyring)[,2])
      {
        apiKeyStore[[i]] <- keyring::key_get("rccola", i, keyring)
      }
    }
    # Check again if it's set properly
    if(!key_saved(apiKeyStore, i))
    {
      # Pull from knit with params if that exists
      if(exists("params") && !is.null(params[[i]]) && params[[i]] != "")
      {
        # Pull from Rmarkdown parameters
        apiKeyStore[[i]] <- apiKeyStore[[i]]
      } else # Ask the user for it
      {
        apiKeyStore[[i]] <- getPass::getPass(msg=paste("Please enter RedCap API_KEY for", i))
      }

      if(!is.null(keyring))
      {
        keyring::key_set_with_value("rccola", i, apiKeyStore[[i]], keyring)
      }
    }

    tryCatch(
      if(is.null(forms) || !(i %in% names(forms)))
      {
        assign(i, readRC(apiUrl, apiKeyStore[[i]],...), envir=dest)
      } else
      {
        for(j in forms[[i]])
        {
          assign(paste0(i,".",j), readRC(apiUrl, apiKeyStore[[i]],forms=j,...), envir=dest)
        }
      },
      error = function(e)
      {
        if(substr(e$message, 1, 3) == "403")
        {
          rm(i, envir = apiKeyStore)
          if(!is.null(keyring)) keyring::key_delete("rccola", i, keyring)
        }
        stop(e)
      }
    )
  }
  return(invisible())
}
