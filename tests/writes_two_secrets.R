require(rccola)


try(keyring::keyring_delete("keytest"))

passFUN1 <- function(msg, ...)
{
  last <- tail(strsplit(msg,split=" ")[[1]],1)
  if(last == "keytest") "testing123" else last
}

drinkREDCap(c("secret1", "secret2"),
          keyring="keytest",
          passwordFUN=passFUN1,
          FUN=function(key, ...) {
  return(key)
} )

if(secret1 != "secret1") stop("Did not save secret1 properly, pass 1")
if(secret2 != "secret2") stop("Did not save secret2 properly, pass 1")

rm(secret1, secret2)

# This function doesn't know the secrets...
passFUN2 <- function(msg, ...)
{
  "testing123"
}

drinkREDCap(c("secret1", "secret2"),
          keyring="keytest",
          passwordFUN=passFUN2,
          FUN=function(key, ...) {
  return(key)
} )

if(secret1 != "secret1") stop("Did not save secret1 properly, pass 2")
if(secret2 != "secret2") stop("Did not save secret2 properly, pass 2")
