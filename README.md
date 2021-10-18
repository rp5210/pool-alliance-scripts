# pool-alliance-scripts

A set of scripts intended to manage custom Cardano SMASH servers for pool alliances.

checkAlliance.sh

Should be run as a scheduled job, but can also be run manually.
Be sure to edit the noted section in the script to input the correct alliance name and json URL
Unfortunately, as there is not a current standardized json format for pool alliances you will need to change the path used to pull the pool IDs out of the json using jq (also noted in the script).
