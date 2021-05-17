# purge-artifacts

**INTERNAL USE ONLY:** This GitHub action is not intended for general use.  The only reason 
why this repo is public is because GitHub requires it.

Purges old deployment related artifacts.

This requires that the **nforgeio/artifacts** repo be already checked out on the job runner VMs
at **%NF_ROOT%\artifacts**.  The action works by:

1. Pulling any remote changes
2. Reading the integer value from **setting-retentions-days**
3. Recursively listing all of the files looking for files starting with timestamps like: "2021-05-08T04_27_27Z-"
4. Deleting any files older than the reetention setting
5. Pushing any changes to the remote

