# rccola export Records from REDCap while keeping API_KEYs safe
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


#' Default function to read from REDCap
#'
#' @param key the api key of interest. The package provides this.
#' @param ... Additional arguments passed to \code{\link[redcapAPI]{exportRecords}}. Should contain url as an argument.
#' @return data.frame containing requested REDCap data.
#'
#' @importFrom redcapAPI redcapConnection
#' @importFrom redcapAPI exportRecords
#'
#' @examples
#' \dontrun{data <- sipREDCap(keyring::key_get("rccola", "database_name", "project_name"))}
#'
#' @export
sipREDCap <- function(key, ...)
{
  args <- list(...)
  redcapAPI::exportRecords(redcapAPI::redcapConnection(url=args[["url"]],token=key), ...)
}

#' exportRecords from REDCap
#'
#' exportRecords from multiple REDCap databases directly into environment
#' variables requested using API_KEY stored in keyring.
#'
#' @param databases character; vector of REDCap databases to export records from.
#'    Can be a named vector, and the name is used as the environment variable
#'    to store resulting data in.
#' @param url character; url of REDCap server
#' @param ... Additional arguments passed to \code{\link[rccola]{drinkREDCap}}
#' which in turn passes most to \code{\link[redcapAPI]{exportRecords}}.
#' @return invisible NULL
#'
#' @examples
#' \dontrun{exportRecords(c("test"="testDatabase"), keyring="test", url="http://someurl.here")}
#'
#' @export
exportRecords <- function(variables=databases, url, ...) drinkREDCap(FUN = sipREDCap, ...)

