
# Internal function to read MetaData
readLabel <- function(key, ...)
{
  args <- list(...)
  redcapAPI::exportMetaData(
    redcapAPI::redcapConnection(
      url=args[["url"]],
      token=key),
    ...)
}

#' Export metadata from REDCap
#'
#' Export metadata from REDCap directly into environment variables requested using
#' API_KEY stored in keyring. Will use the database name provided as the
#' variable name or the corresponding name if a named vector.
#'
#' @param databases character; Vector of database names to export Meta Data from.
#' @param url character; The url of the REDCap server
#' @param keyring character; The keyring to access to get API_KEY associated with database name.
#' @param ... Additional arguments passed to \code{\link[redcapAPI]{exportMetaData}}.
#' @return invisible NULL
#'
#' @examples
#' \dontrun{RCexportMeta(c("meta"="testDatabase"), keyring="test", url="http://someurl.here")}
#'
#' @export
RCexportMeta <- function(databases, keyring, url, ...)
  drinkREDCap(variables=databases, keyring=keyring, url=url, FUN = readLabel, ...)

