# aci-l200lab

This is a set of scripts and tools use to generate a docker image that will have the aci-l200lab binary used to evaluate your ACI troubleshooting skill.

It uses the shc_script_converter.sh (build using the following tool https://github.com/neurobin/shc) to abstract the lab scripts on binary format and then the use the Dockerfile to pack everyting on a Ubuntu container with az cli and kubectl.

Any time the L200 lab scripts require an update the github actions can be use to trigger a new build and push of the updated image.
This will take care of building a new script binary as well as new docker image that will get pushed to the corresponding registry.
The actions will get triggered any time a new release gets published.

Here is the general usage for the image and aci-l200lab tool:

Run in docker
```docker run -it sturrent/aci-l200lab:latest```

aci-l200lab tool usage
```
$ aci-l200lab -h
aci-l200lab usage: aci-l200lab -g <RESOURCE_GROUP> -l <LAB#> [-v|--validate] [-r|--region] [-h|--help] [--version]

Here is the list of current labs available:

***************************************************************
*        1. ACI deployment on existing resource group fails
*        2. ACI deployed with wrong image
*        3. ACI checking container logs
***************************************************************

"-g|--resource-group" resource group name
"-l|--lab" Lab scenario to deploy
"-r|--region" region to create the resources
"-v|--validate" Validate a particular scenario
"--version" print version of aci-l200lab
"-h|--help" help info
```
