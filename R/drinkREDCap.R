# rccola load data from REDCap while keeping API_KEYs safe
#
# Copyright (C) 2021 Shawn Garbett, Cole Beck, Hui Wu
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

# For pulling from knit with parameters
globalVariables("params")


  #############################################################################
 ##
## Helper Functions
##
## Check if key is in package environment, aka memory
key_saved <- function(envir, key)
{
  exists(key, envir=envir, inherits=FALSE) &&
  !is.null(envir[[key]])                   &&
  !is.na(envir[[key]])                     &&
  !envir[[key]]==''
}

  #############################################################################
 ##
## The main function
##
#' Provide API_KEYs to function (defaults to load from REDCap) and load
#' data into memory.
#'
#' The first thing it does is check for a yaml config file of
#' the same name as the current directory with a .yml extension
#' one level above. This is intended for production environments
#' where the API_KEY must be stored in a file. If this yaml exists, then it expects this file
#' to contain `apiUrl` and `apiKeys`. `apiUrl` should be a
#' string with the URL of the REDCap instance. `apiKeys` should
#' be a list of variable name keys with values that are their
#' actual REDCap API_KEY. \cr\cr
#' Next it will use an api environment in memory to keep api_keys.
#' If one is knitting with parameters, it will request and store these
#' keys in memory. Otherwise it will request the user enter
#' each key using getPass and store it in memory.\cr\cr
#' IMPORTANT: Make sure that R is set to NEVER save workspace to .RData
#' as this is the equivalent of writing the API_KEY to a local
#' file in clear text.
#'
#' An older loadFromRedcap function maps to this for backward compatibility.
#'
#' @param variables character vector. A list of strings that define the
#'          variables with associated API_KEYs to load into memory. Each
#'          name should correspond to a REDCap project. It can be a named
#'          vector, the names refer to the variables to assign the output
#'          too for the name of the REDCap project associated with the key.
#' @param envir environment. The target environment for the data. Defaults to .Global
#' @param keyring character. Potential keyring, not used by default.
#' @param forms list. A list of forms. Keys are the variable(api_key), each key can contain a vector of forms.
#'              The output variable is now the <variable>.<form>
#' @param FUN function. the function to call. It must have a key argument. If forms are used it should have a forms argument as well.
#'              The default is to call sipREDCap which is a proxy for \code{\link[redcapAPI]{exportRecords}}.
#' @param config string. Defaults to 'auto'. If set to NULL no configuration file is searched for. If set to anything
#'              but 'auto', that will be the config file override that is used if it exists instead of
#'              searching for the ../<basename>.yml.
#' @param assign logical. Does the function write back the variable to envir or not. Defaults to TRUE.
#' @param passwordFUN function. Function to get the password for the keyring. Defaults to getPass::getPass().
#' @param \dots Additional arguments passed to FUN.
#' @return Nothing
#'
#' @examples
#' \dontrun{
#'   drinkREDCap("database", "myproject")
#' }
#'
#' @importFrom getPass getPass
#' @importFrom yaml read_yaml
#' @importFrom keyring key_get
#' @importFrom keyring key_list
#' @importFrom keyring key_set_with_value
#' @importFrom keyring keyring_create
#' @importFrom keyring keyring_list
#' @importFrom keyring keyring_unlock
#' @importFrom keyring keyring_is_locked
#'
#' @rdname drinkREDCap
#' @export
#'
drinkREDCap    <- function(variables,
                           keyring   = NULL,
                           envir     = NULL,
                           forms     = NULL,
                           FUN       = sipREDCap,
                           config    = 'auto',
                           assign    = TRUE,
                           passwordFUN = getPass::getPass,
                           ...)
{
  # Use the global environment for variable storage unless one was specified
  dest <- if(is.null(envir)) globalenv() else envir

  varnames <- if(is.null(names(variables))) variables else names(variables)

  # If the variable exists, clear from memory
  if(assign)
  {
    for(i in seq_along(variables))
    {
      if(is.null(forms) || !(variables[i] %in% names(forms)))
      {
        if(exists(varnames[i], envir=dest, inherits=FALSE)) rm(list=varnames[i], envir=dest)
      } else
      {
        for(j in forms[[variables[i]]])
        {
          v <- paste0(varnames[i], ".", j)
          if(exists(v, envir=dest, inherits=FALSE)) rm(list=v, envir=dest)
        }
      }
    }
  }

  # Use config if it exists
  config_file <- if(config == 'auto')
  {
    file.path("..", paste0(basename(getwd()),".yml"))
  } else
  {
    config
  }
  if(!is.null(config_file) && file.exists(config_file))
  {
    config <- read_yaml(config_file)
    config <- config$rccola
    keys   <- config$keys
    args   <- c(config$args, list(...))

    for(i in seq_along(variables))
    {
      args$key  <- keys[[variables[i]]]
      args$form <- NULL
      if(is.null(forms) || !(variables[i] %in% names(forms)))
      {
        data <-  do.call(FUN, args)
        if(assign) base::assign(varnames[i], data, envir=dest)
      } else
      {
        for(j in forms[[variables[i]]])
        {
          args$form <- j
          data <- do.call(FUN, args)
          if(assign) base::assign(paste0(varnames[i],".",j), data, envir=dest)
        }
      }
    }
    return(invisible())
  }

  # Create an environment to house API_KEYS locally
  if(!exists("apiKeyStore", inherits=FALSE)) apiKeyStore <- new.env()

  # Was a keyring specified?
  if(!is.null(keyring))
  {
    state <- keyring::keyring_list()
    state <- state[state$keyring==keyring,]

    # If so, does it exist?
    if(nrow(state) == 1)
    {
      # Is it locked
      if(state$locked)
      {
        password <- passwordFUN(msg =
          paste0("Please enter password to unlock rccola keyring ",keyring, " "))
        keyring::keyring_unlock(keyring, password)
      }
    } else # Keyring does not exist
    {
      password <- passwordFUN(msg =
        paste0("Creating keyring. Enter password for the rccola keyring ",
               keyring, " "))
      # Create keyring if it doesn't exist
      keyring::keyring_create(keyring, password)
    }
  }

  # For each dataset requested
  for(i in seq_along(variables))
  {
    # If the API_KEY doesn't exist go look for it

    # Does it exist in a secret keyring, use that
    if(!key_saved(apiKeyStore, variables[i]))
    {
      if(!is.null(keyring) &&
         keyring %in% (keyring::keyring_list()[,1]) &&
         variables[i] %in% keyring::key_list("rccola", keyring)[,2])
      {
        apiKeyStore[[variables[i]]] <- keyring::key_get("rccola", variables[i], keyring)
      }
    }
    # Check again if it's set properly
    if(!key_saved(apiKeyStore, variables[i]))
    {
      # Pull from knit with params if that exists
      if(exists("params") && !is.null(params[[variables[i]]]) && params[[variables[i]]] != "")
      {
        # Pull from Rmarkdown parameters
        apiKeyStore[[variables[i]]] <- params[[variables[i]]]
      } else # Ask the user for it
      {
        apiKeyStore[[variables[i]]] <- passwordFUN(msg=paste("Please enter RedCap API_KEY for", variables[i]))
      }

      if(!is.null(keyring))
      {
        keyring::key_set_with_value("rccola", username=i, password=apiKeyStore[[variables[i]]], keyring=keyring)
      }
    }

    withCallingHandlers(
      if(is.null(forms) || !(variables[i] %in% names(forms)))
      {
        data <- FUN(apiKeyStore[[variables[i]]], ...)
        if(assign) base::assign(varnames[i], data, envir=dest)
      } else
      {
        for(j in forms[[i]])
        {
          data <- FUN(apiKeyStore[[variables[i]]],forms=j,...)
          if(assign) base::assign(paste0(varnames[i],".",j), data, envir=dest)
        }
      },
      error = function(e)
      {
        if(substr(e$message, 1, 3) == "403")
        {
          rm(varnames[i], envir = apiKeyStore)
          if(!is.null(keyring)) keyring::key_delete("rccola", variables[i], keyring)
        }
        stop(e)
      }
    )
  }

  return(invisible())
}
