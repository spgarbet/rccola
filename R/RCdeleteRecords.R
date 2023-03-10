# rccola delete Records to REDCap while keeping API_KEYs safe
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

recycleREDCap <- function(key, ...)
{
  args <- list(...)
  redcapAPI::importRecords(redcapAPI::redcapConnection(url=args[["url"]],token=key), ...)
}

#' importRecords to REDCap
#'
#' importRecords to REDCap directly into environment variables requested using
#' API_KEY stored in keyring.
#'
#' @param database character; The name given to the REDCap database.
#' @param records character; A vector of record_ids to delete
#' @param url character; The url of the REDCap server
#' @param ... Additional arguments passed to \code{\link[redcapAPI]{deleteRecords}}. Should contain url as an argument.
#' @return invisible NULL
#'
#' @examples
#' \dontrun{exportRecords(c("test"="testDatabase"), keyring="test", url="http://someurl.here")}
#'
#' @export
deleteRecords <- function(database, records, ...)
{
  if(length(database) > 1) stop("deleteRecords can only deal with one REDCap database at a time")
  drinkREDCap(variables=database, records=records, url=url, FUN=bottleREDCap, ...)
}

