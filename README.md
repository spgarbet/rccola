# RedCap CryptO Locker for Api_keys (rccola)

A project to assist in the management of API_KEYS to pull [REDCap](https://projectredcap.org/) data using secure practices. The interface will work with anything pulling data into a variable that needs an API_KEY kept secure.

## The Problem

An API_KEY is your username and password rolled into one. This long hexadecimal string provides access into REDCap repositories. If these repositories contain PHI, HIPAA has a $100 per patient record minimum fine. This means the inadvertent leakage of a REDCap API_KEY can be very *expensive* and result in legal exposure.

The risk of exposure is very high if one simply hard codes the API_KEY into a report. If one is sharing with colleagues, git is commonly used to version code. The moment such code is pushed to a public repository such as [github.com](https://github.com), that API_KEY is now shared with the world, and by proxy potentially all that clinical data. 

Even storing the API_KEY(s) in a local file in the project is bad for similar reasons. It's quite easy for git to pick up that file and begin versioning it.

Storing in plain text outside the project directory is better, but the problem that the API_KEY is still present in plain text is the equivalent of storing all that clinical data on the drive in plain text. 

## The solution

This package `rccola`, **R**ed**C**ap **C**rytp**O** **L**ocker for **A**pi_keys. provides a simple solution to this problem. It keeps the API_KEY(s) in memory in an R session when working. IMPORTANT: Make sure R is set to *never* save the .RData of the session or one is back to yet another plain text password save on the local drive. [See r-bloggers](https://www.r-bloggers.com/2017/04/using-r-dont-save-your-workspace/) and [stackoverflow](https://stackoverflow.com/questions/4996090/how-to-disable-save-workspace-image-prompt-in-r). The API_KEY(s) are stored in an encrypted keyring when not working. The system will prompt for a keyring password initially and the keys. Then it will and save and retrieve as needed later in ones workflow. It is also designed to work with a production report server by allowing a production configuration to override usage of a cryptolocker. Thus the path from a statistician developing a report to a production server requires no code changes.

## Installing

    devtools::install_github("r-lib/keyring")
    devtools::install_github("spgarbet/rccola")
    
The latest version of keyring supports rccola password operations inside knitr.

## Knit with Parameters option

For the purposes of demonstration, we shall assume that there are two REDCap projects that need to be summarized in a report:

  * Intake
  * Details
  
For local knitting from RStudio if one wishes to use parameters, the header of the file would look  like this:

    ---
    title: "A Wonderful Report"
    author: "Yours Truly"
    date: "Today"
    output:
      html_document: default
      pdf_document: default
    params:
      intake:
        label: Enter your RedCap API Token for Intake
        value: '' # NEVER EVER PUT AN API_KEY IN THIS FILE!
        input: password
      details:
        label: Enter your RedCap API Token for Details
        value: '' # NEVER EVER PUT AN API_KEY IN THIS FILE!
        input: password
    ---
    
    ```{r setup, include=FALSE}
    knitr::opts_chunk$set(echo = FALSE, warning=FALSE, message=FALSE)
    
    library(rccola)
    
    drinkREDCap(c("intake", "details"), keyring="myreportname")
    
    ...
    
The document can now be knitted with `Knit -> Knit with Parameters`. It also works when running chunks from the console. Two variables are now sitting in memory `intake` and `details` with the contents of those two RedCap repositories.

## Keyring Storage

Using a keyring removes the need to knit with parameters and entering the API_KEY with each new session, and the keys are stored in local encrypted storage. Only the user specified password to the cryptolocker keyring is needed once the keyring is created to load the API_KEYs. This is a secure and convenient method and the recommended usage.

See the [keyring](https://github.com/r-lib/keyring) github page for details on configuring your keyring storage to use a preferred service if you desire. It will default to a password protected encrypted user file.

The `"service"` used for all keyrings is `"rccola"`. The keyring created by this package will be whatever string you pass as the `keyring=`. Thus API_KEYs could be shared between reports as well via using the same keyring. However, since they are keyed via their variable names--if one used a single keyring for all each RedCap database would need a distinct variable name that would be consistent across projects. Otherwise, there could be a namespace collision and it could load the wrong database into a variable. Be very careful with naming when using a shared keyring between projects. 

If you wish to delete the keys stored in the keyring, simply: `keyring::keyring_delete("your_keyring_name")`. The password to a keyring is established the first time it's created. If you don't remember or there was a mistake this is the method to reset the
keyring and start over.

To delete a single key from a keyring the command is:
`keyring::key_delete('rccola', 'your_variable_name', 'your_keyring_name')`

### Mac OS Users

Some versions of MacOS insist on a password with each round trip to the crypto locker.
If prompted over and over for a password, one can override using the MacOS provided
crypto locker and use a local file based one without this issue.

An Rmarkdown header would look something like this to override using the system 
keyring with this issue.
    
    ```{r setup, include=FALSE}
    knitr::opts_chunk$set(echo = TRUE)
    
    library(rccola)
    
    options(keyring_backend="file")
    ```


## Forms option

One can load forms from a database. Continuing the above example let's imagine that the `intake` project has two forms: `consent` and `randomization`.

    drinkREDCap(variables           = c("intake", "details"),
                keyring             = "myreportname",
                forms=list("intake" = c("consent", "randomization")))
                   
The resulting variables in memory are, which were pulled from the intake API_KEY and the details API_KEY.

  * intake.consent
  * intake.randomization
  * details
  
## Inversion of Control

redcapAPI::exportRecord is only the default, anything that needs key management and returns a variable is supported by this library. A function supplied to the `FUN=` argument
can be of either of these two signatures: `function(key, ...)` or `function(key, forms, ...)` if
the forms argument is used.

Let's say we have the above examples and wish to use a curl method.

    library(RCurl)

    rcurl_load <- function(key, forms, ...)
    {
      data <- postForm(
        'https://redcap.vanderbilt.edu/api/',
        token=key,
        content='record',
        format='csv',
        forms=forms,
        fields=c("record_id"),
        rawOrLabel='label',
        exportDataAccessGroups = TRUE
     )
     read.csv(file             = textConnection(data),
              header           = TRUE,
              sep              = ",",
              na.strings       = c(".","","NA","na"),
              stringsAsFactors = FALSE)
    }
    
    drinkREDCap(c("intake", "details"),
                keyring="myreportname",
                forms=list(
                  "intake"  = c("consent", "randomization")
                )
                FUN=rcurl_load)

This calls the user defined function rcurl_load and places in user space three
variables: `intake.consent`, `intake.randomization`, and `details`. 

## Production Environments

For automated processes the API_KEYS in a file are generally required. These automated servers are usually security hardened with 
very tightly controlled access. To facilitate the smooth transition
to a production environment, the `config` option can be used to specify a configuration file with the keys. If `config` is set to 
'auto', the default, then it takes the name of the current directory and looks above it for a file of the same name with a ".yml" extension as the config file. If `config` is set to NULL this override behavior is not followed. If the config file does 
not exist it prompts the user as usual.

An example yaml configuration file would look something like the following:

    other-config-stuff1: blah blah
    rccola:
      args:
        url: https://redcap.vanderbilt.edu/api/
      keys:
        intake: THIS_IS_THE_INTAKE_DATABASE_APIKEY
        details: THIS_IS_THE_DETAILS_DATABASE_APIKEY
    other-config-stuff2: blah blah
    other-config-stuff3: blah blah
    ...
    
If one doesn't wish for the specified function to be assigned back as a variable
in the environment, then the `assign=FALSE` argument can be used. This allows for more complex interactions, such as writing back to a RedCap database.
