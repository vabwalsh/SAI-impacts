#!/bin/bash


CURL_VERSION=$(curl --version | grep -oie "curl [0-9][0-9.]*" | head -n 1 | awk '{print $2}')
if [ -z "$CURL_VERSION" ]
then
CURL_VERSION=PARSE_ERROR
fi

CURL_USER_AGENT="curl/$CURL_VERSION/esg/4.0.0-20221018-180016/created/2022-11-01T09:51:06-06:00"


##############################################################################
#
# Climate Data Gateway download script
#
#
# Generated by: NCAR Climate Data Gateway
#
# Template version: 0.4.7-curl-checksum
#
#
# Your download selection includes data that might be secured using API Token based
# authentication. Therefore, this script can have your api-token. If you
# re-generate your API Token after you download this script, the download will
# fail. If that happens, you can either re-download this script or you can replace
# the old API Token with the new one by going to the Account Home:
#
# https://www.earthsystemgrid.org/account/user/account-home.html
#
# and clicking on "API Token" link under "Personal Account". You will be asked
# to log into the application before you can view your API Token.
#
# Dataset
# ucar.cgd.cesm2.waccm6.ssp245.atm.proc.monthly_ave.ANRAIN
# 3f551bf0-f66c-4e9d-ae4e-0dcf94563386
# https://www.earthsystemgrid.org/dataset/ucar.cgd.cesm2.waccm6.ssp245.atm.proc.monthly_ave.ANRAIN.html
# https://www.earthsystemgrid.org/dataset/id/3f551bf0-f66c-4e9d-ae4e-0dcf94563386.html
#
# Dataset Version
# 1
# fb9ecf41-5fdb-4ca7-92e4-8f92103ccb53
# https://www.earthsystemgrid.org/dataset/ucar.cgd.cesm2.waccm6.ssp245.atm.proc.monthly_ave.ANRAIN/version/1.html
# https://www.earthsystemgrid.org/dataset/version/id/fb9ecf41-5fdb-4ca7-92e4-8f92103ccb53.html
#
##############################################################################

CACHE_FILE=.md5_results
MAX_RETRY=3


usage() {
    echo "Usage: $(basename $0) [flags]"
    echo "Flags is one of:"
    sed -n '/^while getopts/,/^done/  s/^\([^)]*\)[^#]*#\(.*$\)/\1 \2/p' $0
}
#defaults
debug=0
clean_work=1
verbose=1

#parse flags

while getopts ':pdvqko:' OPT; do

    case $OPT in

        p) clean_work=0;;       #	: preserve data that failed checksum
        o) output="$OPTARG";;   #<file>	: Write output for DML in the given file
        d) debug=1;;            #	: display debug information
        v) verbose=1;;          #       : be more verbose
        q) quiet=1;;            #	: be less verbose
        k) cert=1;;             #	: add --insecure (do not check certificate)
        \?) echo "Unknown option '$OPTARG'" >&2 && usage && exit 1;;
        \:) echo "Missing parameter for flag '$OPTARG'" >&2 && usage && exit 1;;
    esac
done
shift $(($OPTIND - 1))

if [[ "$output" ]]; then
    #check and prepare the file
    if [[ -f "$output" ]]; then
        read -p "Overwrite existing file $output? (y/N) " answ
        case $answ in y|Y|yes|Yes);; *) echo "Aborting then..."; exit 0;; esac
    fi
    : > "$output" || { echo "Can't write file $output"; break; }
fi

    ((debug)) && echo "debug=$debug, cert=$cert, verbose=$verbose, quiet=$quiet, clean_work=$clean_work"

##############################################################################


check_chksum() {
    local file="$1"
    local chk_type=$2
    local chk_value=$3
    local local_chksum

    case $chk_type in
        md5) local_chksum=$(md5 "$file" | awk {'print $NF'});;
        *) echo "Can't verify checksum." && return 0;;
    esac

    #verify
    ((debug)) && echo "local:$local_chksum vs remote:$chk_value"
    diff -q <(echo $local_chksum) <(echo $chk_value) >/dev/null
}

download() {

    curl="curl -L -C - --user-agent $CURL_USER_AGENT"

    if [[ "$cert" ]]; then
        curl="curl --insecure -L -C - --user-agent $CURL_USER_AGENT"
    else
        curl="curl -L -C - --user-agent $CURL_USER_AGENT"
    fi

    ((quiet)) && curl="$curl -s" || { ((!verbose)) && curl="$curl -S"; }

    ((debug)) && echo "curl command: $curl"

    while read line
    do
        # read csv here document into proper variables
        eval $(awk -F "' '" '{$0=substr($0,2,length($0)-2); $3=tolower($3); print "file=\""$1"\";url=\""$2"\";chksum_type=\""$3"\";chksum=\""$4"\""}' <(echo $line) )

        #Process the file
        echo -n "$file ..."

        #are we just writing a file?
        if [ "$output" ]; then
            echo "$file - $url" >> $output
            echo ""
            continue
        fi

        retry_counter=0

        while : ; do
                #if we have the file, check if it's already processed.
                [ -f "$file" ] && cached="$(grep $file $CACHE_FILE)" || unset cached

                #check it wasn't modified
                if [[ -n "$cached" && "$(stat -f "%m" $file)" == $(echo "$cached" | cut -d ' ' -f2) ]]; then
                    echo "Already downloaded and verified"
                    break
                fi

                # (if we had the file size, we could check before trying to complete)
                echo "Downloading"
                $curl -o "$file" $url --header "authorization: api-token BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6" || { failed=1; break; }

                #check if file is there
                if [[ -f "$file" ]]; then
                        ((debug)) && echo file found
                        if ! check_chksum "$file" $chksum_type $chksum; then
                                echo "  $chksum_type failed!"
                                if ((clean_work)); then
                                        rm "$file"

                                        #try again up to n times
                                        echo -n "  Re-downloading..."

                                        if [ $retry_counter -eq $MAX_RETRY ]
                                        then
                                            echo "  Re-tried file $file $MAX_RETRY times...."
                                            break
                                        fi
                                        retry_counter=`expr $retry_counter + 1`

                                        continue
                                else
                                        echo "  don't use -p or remove manually."
                                fi
                        else
                                echo "  $chksum_type ok. done!"
                                echo "$file" $(stat -f "%m" $file) $chksum >> $CACHE_FILE
                        fi
                fi
                #done!
                break
        done

        if ((failed)); then
            echo "download failed"

            unset failed
        fi

    done <<EOF--dataset.file.url.chksum_type.chksum
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.001.cam.h0.ANRAIN.201501-206412.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.001/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.001.cam.h0.ANRAIN.201501-206412.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' 'c983257597ddd2dbd97eb92dedfe8e08'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.001.cam.h0.ANRAIN.206501-210012.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.001/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.001.cam.h0.ANRAIN.206501-210012.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' '2ccf747b3216dbb7a63bd1448d799a3c'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.002.cam.h0.ANRAIN.201501-206412.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.002/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.002.cam.h0.ANRAIN.201501-206412.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' 'efa00c9edeec268a9051bde48b3ae11b'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.002.cam.h0.ANRAIN.206501-210012.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.002/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.002.cam.h0.ANRAIN.206501-210012.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' '2390bbecdd957573184d9005be1f691a'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.003.cam.h0.ANRAIN.201501-206412.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.003/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.003.cam.h0.ANRAIN.201501-206412.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' 'bd984e2f696499d916fc375ddc8f87f8'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.003.cam.h0.ANRAIN.206501-210012.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.003/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.003.cam.h0.ANRAIN.206501-210012.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' 'fa278dc628d22f22b6cfcc7a8e48dcda'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.004.cam.h0.ANRAIN.201501-206412.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.004/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.004.cam.h0.ANRAIN.201501-206412.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' '4abb72ac42787fa46a68834c7bec3db6'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.004.cam.h0.ANRAIN.206501-210012.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.004/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.004.cam.h0.ANRAIN.206501-210012.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' '9dff84f105cb40e11adf3e0e42213468'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.005.cam.h0.ANRAIN.201501-206412.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.005/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.005.cam.h0.ANRAIN.201501-206412.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' 'de085b6687aacb6ee750fe85e2f1cea8'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.005.cam.h0.ANRAIN.206501-210012.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.005/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.005.cam.h0.ANRAIN.206501-210012.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' '834607432af5163f26a2192a2a34ec06'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.006.cam.h0.ANRAIN.201501-206412.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.006/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.006.cam.h0.ANRAIN.201501-206412.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' '67eec698bcfbf45b159bf2372526df82'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.006.cam.h0.ANRAIN.206501-206912.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.006/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.006.cam.h0.ANRAIN.206501-206912.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' '48ab0c7e8e9baa2aa5b753246ddd5495'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.007.cam.h0.ANRAIN.201501-206412.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.007/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.007.cam.h0.ANRAIN.201501-206412.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' '2ac201f25a62c9942ea8730c029f2960'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.007.cam.h0.ANRAIN.206501-206912.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.007/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.007.cam.h0.ANRAIN.206501-206912.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' 'd693f84889a53cb72c7f7c0233a014cc'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.008.cam.h0.ANRAIN.201501-206412.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.008/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.008.cam.h0.ANRAIN.201501-206412.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' '163f0e93e1c7d912cf656b99d806e330'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.008.cam.h0.ANRAIN.206501-206912.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.008/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.008.cam.h0.ANRAIN.206501-206912.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' '7140d3bf3a3b3dac4bbed9bc04192e68'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.009.cam.h0.ANRAIN.201501-206412.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.009/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.009.cam.h0.ANRAIN.201501-206412.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' '2afd632fdb1b6c1421a072c6e99ffd3a'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.009.cam.h0.ANRAIN.206501-206912.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.009/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.009.cam.h0.ANRAIN.206501-206912.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' '7a1ceab1d01bd09257e7737cbca354d4'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.010.cam.h0.ANRAIN.201501-206412.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.010/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.010.cam.h0.ANRAIN.201501-206412.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' 'e8911c1604f4118ce923b20649920bc4'
'b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.010.cam.h0.ANRAIN.206501-206912.nc' 'https://tds.ucar.edu/thredds/fileServer/datazone/campaign/cesm/collections/CESM2-WACCM-SSP245/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.010/atm/proc/tseries/month_1/b.e21.BWSSP245cmip6.f09_g17.CMIP6-SSP2-4.5-WACCM.010.cam.h0.ANRAIN.206501-206912.nc?api-token=BUUd20REatSAKkH1lOiQvHifT2WUHML2uq3BBUz6' 'md5' '44a0c295aea5eb6f451803108f1a43f0'
EOF--dataset.file.url.chksum_type.chksum

}


#
# MAIN
#
echo "Running $(basename $0) version: $version"

#do we have old results? Create the file if not
[ ! -f $CACHE_FILE ] && echo "#filename mtime checksum" > $CACHE_FILE

download

#remove duplicates (if any)
{ rm $CACHE_FILE && tail | awk '!x[$1]++' | tail > $CACHE_FILE; } < $CACHE_FILE
