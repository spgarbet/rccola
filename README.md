# RCCola

A project to assist in the management of API_KEYS to pull RedCap data in a safe manner.

## The Problem

An API_KEY is your username and password rolled into one. This long hexadecimal string provides access into RedCap repositories. If these repositories contain PHI, HIPAA has a $100 per patient record minimum fine. This means the inadvertent leakage of a RedCap API_KEY is *expensive*.

The risk of exposure is very high if one simply hard codes the API_KEY into a report. If one is sharing with colleagues, git is commonly used to version code. The moment such code is pushed to a public repository such as [github.com](https://github.com], that API_KEY is now shared with the world, and by proxy potentially all that clinical data. 

Even storing the API_KEY(s) in a local file in the project is bad for similar reasons. It's quite easy for git to pick up that file and begin versioning it.

Storing in plain text outside the project directory is better, but the problem that the API_KEY is still present in plain text is the equivalent of storing all that clinical data on the drive in plain text. 

## The solution

This package "RedCap Cola" provides a simple solution to this problem. It keeps the API_KEY(s) in memory in an R session when working. IMPORTANT: Make sure R is set to *never* save the .RData of the session or your back to yet another plain text save on the local drive. The API_KEY(s) are stored in an encrypted keyring when not working. The system will prompt for the keys initially and save and retrieve as needed downstream. It is also designed to work with a production report server at Vanderbilt Biostatistics that emails reports automatically on a repeating basis, with *no changes* to the report. Thus a party can work in their local environment, save their code to a git report. This git repo can be shared with a system administrator who to update a report simply needs to do a git pull.

## Installing

    devtools::install_github("spgarbet/rccola")

## How it works. 

For the purposes of demonstration, we shall assume that there are two RedCap projects that need to be summarized in a report:

  * Intake
  * Details
  
For local knitting from RStudio, the header of the file should look something like this:

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
    
    loadFromRedcap(c("intake", "details"), keyring="myreportname")
    
    ...
    
The document can now be knitted with `Knit -> Knit with Parameters`. It also works when running chunks from the console. Two variables are now sitting in memory `intake` and `details` with the contents of those two RedCap repositories.


    
