#!/usr/bin/sudo /bin/bash

channel_number=$1
channel_type=$2
wlan_interface=$3
facial_recognition_file=$4

SLEEP_TIME=2
SWITCH_WAIT_TIME=5
PACKET_DELAY=0

injection_mode () {
    echo "Switching $wlan_interface to inject........................................"
    ip link set $wlan_interface down
    echo "Deleting mon0...................................................."
    iw dev mon0 del 2>/dev/null 1>/dev/null
    echo "Bringing up firmware............................................."
    modprobe -r iwlwifi mac80211 cfg80211
    modprobe iwlwifi debug=0x40000
    echo "Running ip link show on $wlan_interface, looping until success............."  
    ip link show $wlan_interface 2>/dev/null 1>/dev/null
    while [ $? -ne 0 ]; do
        ip link show $wlan_interface 2>/dev/null 1>/dev/null
    done
    echo "Setting $wlan_interface into monitor mode.................................."
    iw dev $wlan_interface set type monitor 2>/dev/null 1>/dev/null
    mode_change=$?
    while [ $mode_change -ne 0 ]; do
        ip link set $wlan_interface down 2>/dev/null 1>/dev/null
        iw dev $wlan_interface set type monitor 2>/dev/null 1>/dev/null
        mode_change=$?
    done
    echo "Bringing up $wlan_interface ..............................................."
    ip link set $wlan_interface up
    echo "Adding monitor to $wlan_interface ........................................."
    iw dev $wlan_interface interface add mon0 type monitor
    echo "Bringing up mon0................................................."
    ip link set mon0 up
    echo "Killing default wireless interface, wlan0........................"
    ip link set wlan0 down
    echo "Setting channel on mon0 to $channel_number $channel_type .............................."
    iw dev mon0 set channel $channel_number $channel_type
    channel_set=$?
    while [ $channel_set -ne 0 ]; do
        ip link set $wlan_interface down 2>/dev/null 1>/dev/null
        iw dev $wlan_interface set type monitor 2>/dev/null 1>/dev/null
        ip link set $wlan_interface up
        iw dev mon0 set channel $channel_number $channel_type
        channel_set=$?
        if [ $channel_set -eq 0 ]; then
            echo "Fixed problem with set channel command..........................."
        fi
    done
    echo "Setting monitor_tx_rate.........................................."
    echo 0x4101 | sudo tee `sudo find /sys -name monitor_tx_rate`
    echo "Injection mode active!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
}

monitor_mode () {
    echo "Switching $wlan_interface to monitor......................................."
    echo "Bringing up firmware............................................."
    modprobe -r iwlwifi mac80211 cfg80211
    modprobe iwlwifi connector_log=0x5
    echo "Bringing down $wlan_interface ............................................."
    ip link set $wlan_interface down 2>/dev/null 1>/dev/null
    echo "Setting $wlan_interface into monitor mode.................................."
    iw dev $wlan_interface set type monitor 2>/dev/null 1>/dev/null
    mode_change=$?
    while [ $mode_change -ne 0 ]; do
        ip link set $wlan_interface down 2>/dev/null 1>/dev/null
        iw dev $wlan_interface set type monitor 2>/dev/null 1>/dev/null
        mode_change=$?
    done
    echo "Bringing up $wlan_interface ..............................................."
    ip link set $wlan_interface up
    wlan_interface_up=$(ip link show up | grep $wlan_interface | wc -l)
    while [ $wlan_interface_up -ne 1 ]
    do
        ip link set $wlan_interface up
        wlan_interface_up=$(ip link show up | grep $wlan_interface | wc -l)
    done
    echo "Bringing down default wireless interface wlan0..................."
    ip link set wlan0 down
    echo "Setting channel to monitor on $wlan_interface to $channel_number $channel_type .................." 
    iw dev $wlan_interface set channel $channel_number $channel_type
    channel_set=$?
    while [ $channel_set -ne 0 ]; do
        ip link set $wlan_interface down 2>/dev/null 1>/dev/null
        iw dev $wlan_interface set type monitor 2>/dev/null 1>/dev/null
        ip link set $wlan_interface up 2>/dev/null 1>/dev/null
        ip link set wlan0 down 2>/dev/null 1>/dev/null
        iw dev $wlan_interface set channel $channel_number $channel_type 2>/dev/null 1>/dev/null
        channel_set=$?
        if [ $channel_set -eq 0 ]; then
            echo "Fixed problem with set channel command..........................."
        fi
    done
    echo "Monitor mode active!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
}

face_signal_overlap() {
    top_aoas=$1
    received_facial_recognition_file=$2
    # Run C++ facial recognition and output one of the angles given to indicate the face is there
    # Output -1 if the face appears nowhere
    # Make the program look for like 1-3 seconds or so
}

pkill log_to_file
monitor_mode

echo "Waiting for LGTM initiation......................................"
rm .lgtm-monitor.dat
./log-to-file/log_to_file .lgtm-monitor.dat &

# Wait for key press or special token to appear in lgtm-monitor.dat
echo "Press 'L' to initiate LGTM from this computer...................."
begin_lgtm=0
input='a'
while [[ $input != 'l' ]] && [[ $begin_lgtm -lt 1 ]]; do
    read -n 1 -s -t 2 -r input
    # TODO: Later this token, "begin-lgtm-protocol", will also include a public key
    begin_lgtm=$(cat .lgtm-monitor.dat | grep "lgtm-begin-protocol" | wc -l)
done

# Key pressed to initiate LGTM
if [[ $input == 'l' ]]; then
    echo "Initiating LGTM protocol........................................."
    pkill log_to_file
    # Sleep for 5 seconds to ensure other party has switched into monitor mode
    sleep $SWITCH_WAIT_TIME
    # undo monitor mode settings....(which are what exactly?)
    # Setup Injection mode
    injection_mode
    # Send "begin-lgtm-protocol", TODO: later this will include a public key
    rm .lgtm-begin-protocol
    echo lgtm-begin-protocol > .lgtm-begin-protocol
    ./packets-from-file/packets_from_file .lgtm-begin-protocol 1 $PACKET_DELAY
    # Switch to monitor mode
    monitor_mode
    # Wait for acknowledgement + facial recognition params, TODO: later it will be ack + recog params + public key
    echo "Awaiting 'facial recognition params'!"
    rm .lgtm-monitor.dat
    ./log-to-file/log_to_file .lgtm-monitor.dat &
    lgtm_ack=0
    while [ $lgtm_ack -lt 1 ]; do
        # Receive ack + params
        lgtm_ack=$(cat .lgtm-monitor.dat | grep "facial-recognition-params-finished" | wc -l)
    done
    pkill log_to_file
    echo "Received 'facial recognition params'!"
    echo "Localizing signal source!"
    chmod 644 .lgtm-monitor.dat
    logged_on_user=$(who | head -n1 | awk '{print $1;}')
    sudo -u $logged_on_user matlab -nojvm -nodisplay -nosplash -r "run('../csi-code/spotfi.m'), exit"
    echo "Successfully localized signal source!"
    # Sleep for 5 seconds to ensure other party has switched into monitor mode.... TODO: Shorten or remove this....
    sleep $SWITCH_WAIT_TIME
    # Switch to injection mode
    injection_mode
    # Send facial recognition params
    echo "Sending 'facial recognition params'!"
    rm .lgtm-facial-recognition-params
    echo facial-recognition-params > .lgtm-facial-recognition-params
    #cat facial-recognition-model >> .lgtm-facial-recognition-params
    cat facial_recognition_file >> .lgtm-facial-recognition-params
    echo facial-recognition-params-finished >> .lgtm-facial-recognition-params
    ./packets-from-file/packets_from_file .lgtm-facial-recognition-params 1
    echo "Checking for face/signal overlap................................."
    # TODO: ADD OUTPUT TO FILE TO SPOTFI FILE SO THAT I CAN RETRIEVE THE TOP-3 AoAS FROM FILE
    top_aoas=$(cat .lgtm-top-aoas)
    face_signal_overlap $top_aoas $received_facial_recognition_file
    # Done!
    echo "LGTM COMPLETE!"
    exit
fi

# Token received from other party to initiate LGTM
if [ $begin_lgtm -gt 0 ]; then
    echo "Other party initiated LGTM protocol.............................."
    # Setup Injection mode
    injection_mode
    # Sleep for 5 seconds to ensure other party has switched into monitor mode....
    sleep $SWITCH_WAIT_TIME
    # Send acknowledgement + facial recognition params, TODO: later this will inlcude a public key
    echo "Sending 'facial recognition params'!"
    rm .lgtm-facial-recognition-params
    echo facial-recognition-params > .lgtm-facial-recognition-params
    #cat facial-recognition-model >> .lgtm-facial-recognition-params
    cat facial_recognition_file >> .lgtm-facial-recognition-params
    echo facial-recognition-params-finished >> .lgtm-facial-recognition-params
    ./packets-from-file/packets_from_file .lgtm-facial-recognition-params 1 $PACKET_DELAY
    # Setup Monitor mode
    monitor_mode
    # Await facial recognition params
    echo "Awaiting 'facial recognition params'!"
    rm .lgtm-monitor.dat
    ./log-to-file/log_to_file .lgtm-monitor.dat &
    lgtm_ack=0
    while [[ $lgtm_ack -lt 1 ]]; do
        # Receive ack + params
        lgtm_ack=$(cat .lgtm-monitor.dat | grep "facial-recognition-params-finished" | wc -l)
    done
    pkill log_to_file
    echo "Received 'facial recognition params'!"
    echo "Localizing signal source!"
    chmod 644 .lgtm-monitor.dat
    logged_on_user=$(who | head -n1 | awk '{print $1;}')
    sudo -u $logged_on_user matlab -nojvm -nodisplay -nosplash -r "run('../csi-code/spotfi.m'), exit"
    echo "Successfully localized signal source!"
    echo "Checking for face/signal overlap................................."
    # Done!
    echo "LGTM COMPLETE!"
    exit
fi