library(redcapAPI)
library(getPass)

if(exists("data")) rm(data) # Remove previous pull
if(!exists("api")) api <- new.env()

if(!exists("token", envir=api))
{
  if(exists("params") && !is.null(params$api_token) && params$api_token != "")
  {
    # Pull from Rmarkdown parameters
    api$token <- params$api_token 
  } else
  {
    # Ask User for Token in a safe manner
    api$token <- getPass(msg="Please enter RedCap API token: ")
  }
}

rcon <- redcapConnection(url="https://redcap.vanderbilt.edu/api/", token=api$token)
tryCatch(data <- exportRecords(rcon, factors = TRUE, labels = TRUE),
    error = function(e) {
      rm(token, envir = api)
      stop(e)
    }
)
rm(rcon)