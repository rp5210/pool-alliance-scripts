# SMASH Server Alliance Management Tool for db-sync v12 and later
# v2.0-beta
# Written by Ryan - PANL Stake Pool
# TG link:  https://t.me/Rp5210
################################################################################
#                       CHANGE THE FOLLOWING TO REPRESENT
#                       YOUR ALLIANCE NAME AND A URL TO THE
#                       RAW JSON FILE CONTAINING THE ALLIANCE
#                       REGISTRY (Note: Must include PoolId keys
################################################################################

ALLIANCE_NAME="Cardano Mission Driven Pools (CMDP)"
ALLIANCE_REGISTRY_URL="https://raw.githubusercontent.com/CardanoMDP/CardanoMDP-adapools-org-alliance/main/cardano-mdp.json"

################################################################################
##     change just the jq path to return only a list of pool ids
################################################################################
REGISTERED_POOLS=`curl $ALLIANCE_REGISTRY_URL --silent | jq -r '.adapools.members' | jq -r '.[].pool_id'`
#################################################################################

################################################################################
#                       DO NOT MODIFY CODE BELOW THIS LINE
################################################################################
#                       DEFINE LISTS OF Pools
################################################################################

echo $ALLIANCE_NAME
LISTED_POOLS=`psql -d cexplorer -t -c "select pool_hash.hash_raw from pool_update inner join pool_hash on pool_update.hash_id = pool_hash.id where registered_tx_id in (select max(registered_tx_id) from pool_update group by hash_id) and not exists ( select * from pool_retire where pool_retire.hash_id = pool_update.hash_id and pool_retire.retiring_epoch <= (select max (epoch_no) from block)) and not exists (select * from delisted_pool where delisted_pool.hash_raw = pool_hash.hash_raw);"`
Number_Listed=`wc -w <<< "$LISTED_POOLS"`
echo Number of listed pools: $Number_Listed

Number_Registered=`wc -w <<< "$REGISTERED_POOLS"`
echo Number of registered pools: $Number_Registered

DELISTED_POOLS=`psql -d cexplorer -t -c "SELECT hash_raw FROM delisted_pool;"`
Number_Delisted=`wc -w <<< "$DELISTED_POOLS"`
echo Number of delisted pools: $Number_Delisted

RETIRED_POOLS=`psql -d cexplorer -t -c "SELECT pool_hash.hash_raw FROM pool_hash join pool_retire on pool_hash.id = pool_retire.hash_id where retiring_epoch <= (select max (epoch_no) from block);"`
Number_Retired=`wc -w <<< "$RETIRED_POOLS"`
echo Number of Retired Pools: $Number_Retired

####################################################################
#               CHECK IF LISTED POOLS ARE REGISTERED
####################################################################
echo ----------------------------------
echo Delisting non-alliance pools
echo ----------------------------------
REG_COUNT=0
UNREG_COUNT=0

for pool in $LISTED_POOLS
do
      if grep -q "${pool:2}" <<< "$REGISTERED_POOLS"; then
                ((REG_COUNT=REG_COUNT+1))
        else
		ticker=`psql -d cexplorer -t -c "select max(ticker_name) from pool_offline_data join pool_hash on pool_hash.id = pool_offline_data.pool_id where pool_hash.hash_raw = '$pool';"`
                echo "$ticker | $pool -- will be delisted"
                psql cexplorer -q -c "INSERT INTO delisted_pool (hash_raw) VALUES ('$pool');"
                ((UNREG_COUNT=UNREG_COUNT+1))
        fi
done

if (($UNREG_COUNT == 0 )); then
        echo "All listed pools are registered with the $ALLIANCE_NAME."
else
        echo $UNREG_COUNT: Pools have been delisted, run again to verify.
fi

####################################################################
#                      CHECK IF REGISTERED POOLS ARE LISTED
####################################################################
echo -----------------------------------
echo Checking if all alliance pools are listed
echo -----------------------------------
LISTED_REG_COUNT=0
UNLISTED_REG_COUNT=0

for pool in $REGISTERED_POOLS
do
	pool="\x"$pool
        if grep -q $pool <<< "$DELISTED_POOLS"; then
                ticker=`psql -d cexplorer -t -c "select ticker_name from pool_offline_data join pool_hash on pool_hash.id = pool_offline_data.pool_id where pool_hash.hash_raw = '$pool';"`
		echo "$ticker | $pool -- is registered and will be listed"
                psql -d cexplorer -c "DELETE FROM delisted_pool WHERE hash_raw='$pool';"
                ((UNLISTED_REG_COUNT=UNLISTED_REG_COUNT+1))
        else
                ((LISTED_REG_COUNT=LISTED_REG_COUNT+1))
        fi
done

if (($UNLISTED_REG_COUNT == 0)); then
        echo $Number_Listed: Pools listed that are registered with the $ALLIANCE_NAME
else
        echo Number of pools listed this run: $UNLISTED_REG_COUNT
fi

####################################################################
#                               CHECK ALLIANCE FOR RETIRED Pools
####################################################################
echo -----------------------------------
echo Checking alliance for retired pools
echo -----------------------------------
RET_COUNT=0
LIVE_COUNT=0
echo "ticker	|			pool_hash			   |  retiring _epoch"
echo "---------------------------------------------------------------------------------------"
for pool in $REGISTERED_POOLS
do
        if grep -q "$pool" <<< "$RETIRED_POOLS"; then
		ticker=`psql -d cexplorer -t -c "select max(ticker_name) from pool_offline_data join pool_hash on pool_hash.id = pool_offline_data.pool_id where pool_hash.hash_raw = '$pool';"`
		epoch_no=`psql -d cexplorer -t -c "select max(retiring_epoch) from pool_retire join pool_hash on pool_hash.id = pool_retire.hash_id where pool_hash.hash_raw = '\x$pool';"`
                echo "$ticker	| $pool | $epoch_no"
                ((RET_COUNT=RET_COUNT+1))
        else
                ((LIVE_COUNT=LIVE_COUNT+1))
        fi
done

if (($RET_COUNT == 0 )); then
        echo All $ALLIANCE_NAME registered pools are live: $LIVE_COUNT
else
        echo $RET_COUNT : pools above have been retired and should be removed from the $ALLIANCE_NAME registry
fi
