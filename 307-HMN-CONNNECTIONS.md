
This file should come from the [shasta_system_configs](https://stash.us.cray.com/projects/DST/repos/shasta_system_configs/browse) repository.
Each system has its own directory in the repository. If this is a new system that doesn't yet have the `hmn_connections.json` file,
 then one will need to be generated from the CCD/SHCD (Cabling Diagram) for the system.

If you do not have this file you can use Docker to generate a new one.

If you need to fetch the cabling diagram, you can use CrayAD logins to fetch it from [SharePoint](http://inside.us.cray.com/depts/CustomerService/CID/Install%20Documents/Forms/AllItems.aspx?RootFolder=%2Fdepts%2FCustomerService%2FCID%2FInstall%20Documents%2FCray%2FShasta%20River&FolderCTID=0x012000C5B40D5925B4534FA7D60FAF1F12BAE9&View={79A8C99F-11EB-44B8-B1A6-02D02755BFC4}).

> NOTE: Docker is available on 1.3 systems if you're making the LiveCD from there. Otherwise, you can install this through zypper or find out how through [Docker's documentation](https://docs.docker.com/desktop/)

```bash
# Replace `${shcd_path}` with the absolute path to the latest CID for the system.
linux:~ # docker run --rm -it --name hms-shcd-parser -v  ${shcd_path}:/input/shcd_file.xlsx -v $(pwd):/output dtr.dev.cray.com/cray/hms-shcd-parser:latest
```
