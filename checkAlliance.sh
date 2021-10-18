# SMASH Server Alliance Management Tool
# v1.0-beta
# Written by Ryan - PANL Stake Pool
# TG link:  https://t.me/Rp5210
################################################################################
#                       CHANGE THE FOLLOWING TO REPRESENT
#                       YOUR ALLIANCE NAME AND A URL TO THE
#                       RAW JSON FILE CONTAINING THE ALLIANCE
#                       REGISTRY (Note: Must include PoolId keys
################################################################################

ALLIANCE_NAME="Cardano Single Pool Alliance (CSPA)"
ALLIANCE_REGISTRY_URL="https://raw.githubusercontent.com/SinglePoolAlliance/Registration/master/registry.json"

################################################################################
## As there is no standard yet for the json structure of alliances, 
##     the line below requires some configuration
##     change just the jq path to return only a list of pool ids
################################################################################
REGISTERED_POOLS=`curl $ALLIANCE_REGISTRY_URL --silent | jq -r '.[].poolId'`
#################################################################################

################################################################################
#                       DO NOT MODIFY CODE BELOW THIS LINE
################################################################################
#						DEFINE LISTS OF Pools
################################################################################

echo $ALLIANCE_NAME

LISTED_POOLS=`psql -d smash -t -c "SELECT DISTINCT pool_id FROM pool_metadata WHERE pool_id NOT IN (SELECT pool_id FROM delisted_pool) AND pool_id NOT IN (SELECT pool_id FROM retired_pool);"`
Number_Listed=`wc -w <<< "$LISTED_POOLS"`
echo Number of listed pools: $Number_Listed

#REGISTERED_POOLS defined above will move here once alliance json format is standardized
Number_Registered=`wc -w <<< "$REGISTERED_POOLS"`
echo Number of registered pools: $Number_Registered

DELISTED_POOLS=`psql -d smash -t -c "SELECT pool_id FROM delisted_pool;"`
Number_Delisted=`wc -w <<< "$DELISTED_POOLS"`
echo Number of delisted pools: $Number_Delisted

RETIRED_POOLS=`psql -d smash -t -c "SELECT pool_id FROM retired_pool;"`
Number_Retired=`wc -w <<< "$RETIRED_POOLS"`
echo Number of Retired Pools: $Number_Retired
####################################################################
#       	CHECK IF LISTED POOLS ARE REGISTERED
####################################################################
echo ----------------------------------
echo Checking if listed pools are registered
echo ----------------------------------
REG_COUNT=0
UNREG_COUNT=0

for pool in $LISTED_POOLS
do
        if grep -q "$pool" <<< "$REGISTERED_POOLS"; then
                ((REG_COUNT=REG_COUNT+1))
        else
                echo "SELECT ticker_name FROM pool_metadata where pool_id='$pool';" | psql smash
                echo "Pool $pool -- will be delisted"
                echo "INSERT INTO delisted_pool (pool_id) VALUES ('$pool');" | psql smash
                ((UNREG_COUNT=UNREG_COUNT+1))
        fi
done

if (($UNREG_COUNT == 0 )); then
        echo "All listed pools are registered with the alliance."
else
        echo $UNREG_COUNT: Pools have been delisted, run again to verify.
fi

####################################################################
#		       CHECK IF REGISTERED POOLS ARE LISTED
####################################################################
echo -----------------------------------
echo Checking if all registered pools are listed
echo -----------------------------------
LISTED_REG_COUNT=0
UNLISTED_REG_COUNT=0

for pool in $REGISTERED_POOLS
do
        if grep -q "$pool" <<< "$DELISTED_POOLS"; then
                echo "Pool $pool -- is registered and will be listed"
                echo "DELETE FROM delisted_pool WHERE pool_id='$pool';" | psql smash
                echo "SELECT pool_id, ticker_name from pool_metadata where pool_id='$pool';" | psql smash
                ((UNLISTED_REG_COUNT=UNLISTED_REG_COUNT+1))
        else
                ((LISTED_REG_COUNT=LISTED_REG_COUNT+1))
        fi
done

if (($UNLISTED_REG_COUNT == 0)); then
        echo Listed and Registered Pools: $Number_Listed
else
        echo Number of pools listed this run: $UNLISTED_REG_COUNT
fi

####################################################################
#				CHECK ALLIANCE FOR RETIRED Pools
####################################################################
echo -----------------------------------
echo Checking alliance for retired pools
echo -----------------------------------
RET_COUNT=0
LIVE_COUNT=0

for pool in $REGISTERED_POOLS
do
        if grep -q "$pool" <<< "$RETIRED_POOLS"; then
                echo "$pool" # --retired pool should be removed from the registry"
                ((RET_COUNT=RET_COUNT+1))
        else
                ((LIVE_COUNT=LIVE_COUNT+1))
        fi
done

echo Number of retired pools still registered with the $ALLIANCE_NAME: $RET_COUNT

if (($RET_COUNT == 0 )); then
        echo All $ALLIANCE_NAME registered pools are live: $LIVE_COUNT
else
        echo The pools above have been retired and should be removed from the $ALLIANCE_NAME registry
        echo Retired Pools to remove:  $RET_COUNT
fi

