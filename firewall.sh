#!/bin/sh
### BEGIN INIT INFO
# Provides:          firewall.sh
# Required-Start:    $syslog $network
# Required-Stop:     $syslog $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start firewall daemon at boot time
# Description:       Firewall script
### END INIT INFO
 
 
PATH=/bin:/sbin:/usr/bin:/usr/sbin
#programme
IPT=/sbin/iptables
# Services tcp/udp input open
OPEN_IP=""
IP_RANGE=""
TCP_SERVICES="22 80 5432" 
UDP_SERVICES="5432"
# Services tcp/udp output open 
REMOTE_TCP_SERVICES="80 3128 8888"
REMOTE_UDP_SERVICES="" 
# Network Administration et Centreon
NETWORK_ADM=""
#response ping (let blank for no)
ping=yes
 
if ! [ -x /sbin/iptables ]; then
 exit 0
fi
 
##########################
#  Firewall rules
##########################
 
fw_start () {
 
 
 
################## Input traffic######################
 
# Accept  ping
if [ -n "$ping" ]; then
$IPT -t filter -A INPUT -p icmp -j ACCEPT
$IPT -t filter -A OUTPUT -p icmp -j ACCEPT
fi
 
# Autoriser all loopback traffic mais drop tout 127/8
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A INPUT -d 127.0.0.0/8 -j REJECT
 
#Laisser les connexions deja existantes
$IPT -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
 
 
# Services ouvert pour les ip
if [ -n "OPEN_IP" ] ; then
for IP in $OPEN_IP; do
if [ -n "$TCP_SERVICES" ] ; then
for PORT in $TCP_SERVICES; do
 $IPT -A INPUT -p tcp --src ${IP} --dport ${PORT} -j ACCEPT
done
fi
if [ -n "$UDP_SERVICES" ] ; then
for PORTUDP in $UDP_SERVICES; do
 $IPT -A INPUT -p udp --src ${IP} --dport ${PORTUDP} -j ACCEPT
done
fi
done
fi
# Services ouvert pour les range
if [ -n "IP_RANGE" ] ; then
for IPR in $IP_RANGE; do
if [ -n "$TCP_SERVICES" ] ; then
for PORT in $TCP_SERVICES; do
 $IPT -A INPUT -p tcp --dport ${PORT} -m iprange --src-range ${IPR}  -j ACCEPT
done
fi
if [ -n "$UDP_SERVICES" ] ; then
for PORTUDP in $UDP_SERVICES; do
 $IPT -A INPUT -p udp --dport ${PORTUDP} -m iprange --src-range ${IPR}  -j ACCEPT
done
fi
done
fi
 
 
#  Laisser ouvert tcp et udp pour le reseau d'administration
if [ -n "$NETWORK_ADM" ] ; then
for IP in $NETWORK_ADM; do
 $IPT -A INPUT -p tcp --src ${IP}  -j ACCEPT
 $IPT -A INPUT -p udp --src ${IP}  -j ACCEPT
done
fi
 
#JOURNALISATION INPUT
$IPT -A INPUT -j LOG
 
 
# Output:
$IPT -A OUTPUT -j ACCEPT -o lo
$IPT -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
# ICMP
$IPT -A OUTPUT -p icmp -j ACCEPT
# APT mirror:
 
$IPT -A OUTPUT -p tcp -d 10.237.29.235 --dport 80 -j ACCEPT
# ouput:
if [ -n "$REMOTE_TCP_SERVICES" ] ; then
for PORT in $REMOTE_TCP_SERVICES; do
 $IPT -A OUTPUT -p tcp --dport ${PORT} -j ACCEPT
done
fi
if [ -n "$REMOTE_UDP_SERVICES" ] ; then
for PORT in $REMOTE_UDP_SERVICES; do
 $IPT -A OUTPUT -p udp --dport ${PORT} -j ACCEPT
done
fi
# Journalisation OUTPUT
$IPT -A OUTPUT -j LOG
 
 
$IPT -A OUTPUT -j REJECT
$IPT -P OUTPUT DROP
# network protections
 
echo 1 > /proc/sys/net/ipv4/tcp_syncookies
echo 0 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
echo 1 > /proc/sys/net/ipv4/conf/all/log_martians
echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route
 
}
 
##########################
# Stop 
##########################
 
fw_stop () {
 
$IPT -F
$IPT -t nat -F
$IPT -t mangle -F
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT
 
}
 
##########################
# Clear t
##########################
 
fw_clear () {
$IPT -F
$IPT -t nat -F
$IPT -t mangle -F
$IPT -P INPUT ACCEPT
$IPT -P FORWARD ACCEPT
$IPT -P OUTPUT ACCEPT
}
 
############################
# Restart 
############################
 
fw_restart () {
fw_stop
fw_start
}
 
############################
# Status
############################
 
fw_statut () {
echo "\033[33mListe des régles:\033[0m"
echo ""
echo "\033[34m------- Régles entrantes ----\033[0m"
$IPT -n -L INPUT -v --line-numbers
echo ""
echo "\033[34m------- Régles routage ----\033[0m"
$IPT -n -L FORWARD -v --line-numbers
echo ""
echo "\033[34m------- Régles sortantes ----\033[0m"
$IPT -n -L OUTPUT -v --line-numbers
}
 
 
case "$1" in
start|restart)
 
 echo -n "\033[33mInitialisation du  firewall:\033[0m"
 fw_restart
 echo "\033[31m[OK]\033[0m"
 ;;
stop)
 echo -n "\033[33mArrêt du firewall:\033[0m"
 fw_stop
 echo "\033[31m[OK]\033[0m"
 ;;
clear)
 echo -n "\033[33mNettoyage firewall des régles:\033[0m"
 fw_clear
 echo "\033[31m[OK]\033[0m"
 ;;
 statut)
 fw_statut
 ;;
 
*)
 echo "Usage: $0 {start|stop|restart|clear|statut}"
 exit 1
 ;;
esac
exit 0
